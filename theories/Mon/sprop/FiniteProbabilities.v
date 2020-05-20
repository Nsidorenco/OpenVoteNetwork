From Coq Require Import ssreflect ssrfun ssrbool.
From Coq Require FunctionalExtensionality List.

From Mon Require Export Base.
From Mon.SRelation Require Import SRelation_Definitions SMorphisms.
From Mon.sprop Require Import SPropBase SPropMonadicStructures MonadExamples SpecificationMonads Monoid DijkstraMonadExamples.
From mathcomp Require Import all_ssreflect all_algebra reals distr.
From Relational Require Import Commutativity.

Import GRing.Theory Num.Theory.

Local Open Scope ring_scope.

Section FinProb.

  Context (R:realType).

  Import SPropNotations.
  Definition is_true_sprop (b:bool) : SProp := if b then True else False.
  Notation "⟦ b ⟧" := (is_true_sprop b).

  Definition unit_interval := { r : R ≫ ⟦0 <= r <= 1⟧}.
  Let I := unit_interval.


  Definition Irel : srelation I := fun i1 i2 => ⟦i1∙1 <= i2∙1⟧.
  Global Instance Irel_preorder : PreOrder Irel.
  Proof.
    constructor.
    move=> ?; rewrite /Irel lerr //.
    move=> x y z ; rewrite /Irel.
    case Hxy: (x∙1 <= y∙1); case Hyz: (y∙1 <= z∙1)=> [] [] [].
    rewrite (ler_trans Hxy Hyz)=> //.
  Qed.

  Definition WI := @MonoCont I Irel _.

  Lemma since_its_true (b:bool) : ⟦b⟧ -> b.
  Proof. by case: b. Qed.

  Lemma its_true_anyway (b:bool) : b -> ⟦b⟧.
  Proof. by case: b. Qed.

  Lemma I_ge0 (x:I) : 0 <= x∙1.
  Proof. by move: (x∙2)=> /since_its_true /andP [-> _]. Qed.

  Lemma I_le1 (x:I) : x∙1 <= 1.
  Proof. by move: (x∙2)=> /since_its_true /andP [_ ->]. Qed.

  Hint Resolve I_ge0.
  Hint Resolve I_le1.

  Program Definition addI (x y : I) : I := ⦑(x∙1 + y∙1) / 2%:~R ⦒.
  Next Obligation.
    apply: its_true_anyway.
    rewrite divr_ge0 ?Bool.andb_true_l ?ler0n ?addr_ge0 //.
    rewrite ler_pdivr_mulr.
    rewrite mul1r [2%:~R]/(1+1) ler_add //.
    rewrite ltr0n //.
  Qed.

  Program Definition mulI (x y:I) : I := ⦑x∙1 * y∙1⦒.
  Next Obligation.
    apply: its_true_anyway.
    rewrite mulr_ge0 //= -(mul1r 1) ler_pmul //.
  Qed.

  Program Definition negI (x:I) : I := ⦑1 - x∙1⦒.
  Next Obligation.
    apply:its_true_anyway.
    rewrite subr_ge0 (I_le1 x) /= ler_subl_addr -{1}(addr0 1) ler_add ?lerr //.
  Qed.

  Definition ProbS := I.
  Definition ProbAr (p:ProbS) := bool.

  Definition ProbM : Monad := Free ProbAr.

  Program Definition barycentric_sum (p:I) (x y: I) : I :=
    ⦑p∙1 * x∙1 + (1-p∙1) * y∙1⦒.
  Next Obligation.
    set p' : I := negI p; change (1-p∙1) with p'∙1.
    apply: its_true_anyway.
    rewrite addr_ge0 ?mulr_ge0 //.
    have: (1 = p∙1*1 + (1 - p∙1)*1) by rewrite !mulr1 addrA [_+1]addrC addrK.
    move=> -> ; by rewrite ler_add // ler_pmul // (I_ge0 (negI p)).
  Qed.

  Program Definition wopProb (p:ProbS) : WI (ProbAr p) :=
    ⦑fun f => barycentric_sum p (f true) (f false) ⦒.
  Next Obligation.
    move=> ? ? H.
   rewrite /Irel /=; apply:its_true_anyway.
   rewrite ler_add // ler_pmul //; try by apply since_its_true, H.
   by rewrite (I_ge0 (negI p)).
  Qed.

  Definition θProb := OpSpecEffObs wopProb.

  Lemma mulIDl : left_distributive mulI addI.
  Proof.
    move=> ? ? ? ; apply sig_eq=> /=.
    by rewrite -mulrA [in t in (_ * t)]mulrC mulrA mulrDl.
  Qed.

  Lemma mulIDr : right_distributive mulI addI.
  Proof.
    move=> ? ? ? ; apply sig_eq=> /=; by rewrite mulrA mulrDr.
  Qed.

  Lemma addIX p1 p2 p3 p4 :
    addI (addI p1 p2) (addI p3 p4) = addI (addI p1 p3) (addI p2 p4).
  Proof.
    apply sig_eq => /=;
      by rewrite -2!mulrDl -2!addrA
                 [in t in _+t]addrA (addrC (p2∙1) (p3∙1)) !addrA.
  Qed.

  Lemma addIC : commutative addI.
  Proof. move=> ? ? ; apply sig_eq => /= ; by rewrite addrC. Qed.

  Lemma mulIC : commutative mulI.
  Proof. move=> ? ? ; apply sig_eq => /= ; by rewrite mulrC. Qed.

  Lemma mulIA : associative mulI.
  Proof. move=> ? ? ? ; apply sig_eq => /= ; by rewrite mulrA. Qed.

  Import FunctionalExtensionality.
  Lemma self_commute (p1 p2 : ProbS) : commute (wopProb p1) (wopProb p2).
  Proof.
    rewrite /commute /wopProb; apply sig_eq=> /=.
    extensionality k; apply sig_eq=> /=.
    rewrite !mulrDr !mulrA.
    do 2 rewrite [((1 - _)* _)as t in t * _]mulrC.
    rewrite 2![(p1∙1 * _)as t in t * _]mulrC.
    rewrite -2!addrA [in t in _+t]addrA [in t in _ + (t + _)]addrC !addrA.
    do 2 f_equal.
  Qed.
End FinProb.


(* Reflection for SProp (not needed in the end) *)

(* Inductive sreflect (P : SProp) : bool -> Type := *)
(* | SReflectT : P -> sreflect P true *)
(* | SReflectF : s~ P -> sreflect P false. *)

(* Lemma andSP (b1 b2 : bool) : sreflect (⟦b1⟧ s/\ ⟦b2⟧) (b1 && b2). *)
(* Proof. case: b1; case: b2 => /=; first left=> //=; right=> [[[] []]]. Qed. *)

(* Definition elimST (P : SProp) (b : bool) : sreflect P b -> ⟦b⟧ -> P. *)
(* Proof. by case=> ? []. Qed. *)

(* Coercion elimST : sreflect >-> Funclass. *)
