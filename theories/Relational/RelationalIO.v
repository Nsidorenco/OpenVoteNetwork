(*********************************************************)
(**       Relational reasoning on IO                    **)
(*********************************************************)

From Coq Require Import ssreflect ssrfun ssrbool.
From Coq Require Import FunctionalExtensionality Arith.PeanoNat List.

From Mon Require Export Base.
From Mon.SRelation Require Import SRelation_Definitions SMorphisms.
From Mon.sprop Require Import SPropBase SPropMonadicStructures MonadExamples SpecificationMonads Monoid DijkstraMonadExamples.
(* From Mon.SM Require Import SMMonadExamples.  *)
From Relational Require Import OrderEnrichedCategory OrderEnrichedRelativeMonadExamples GenericRulesSimple Commutativity.

Import SPropNotations.
Import ListNotations.

Set Primitive Projections.
Set Universe Polymorphism.

Section IOs.
  Context {I1 I2 O1 O2 : Type}.

  Let M1 := IO I1 O1.
  Let M2 := IO I2 O2.

  Let Es1 := list (I1+O1).
  Let Es2 := list (I2+O2).
  Let Es12 := Es1 × Es2.
  Let carrier := Es12 -> SProp.

  Definition Wun :=
    @MonoCont carrier (@Pred_op_order _) (@Pred_op_order_prorder _).

  Program Definition wop1 (s:IOS O1) : Wun (IOAr I1 s) :=
    match s with
    | Read _ => ⦑fun p h => forall i, p i ⟨ inl i :: nfst h, nsnd h ⟩⦒
    | Write o => ⦑fun p h => p tt ⟨ inr o :: nfst h, nsnd h ⟩⦒
    end.
  Next Obligation. move=> ? ? H ? H0 ?; apply H ; apply H0. Qed.
  Next Obligation. move=> ? ? H ? H0 ; apply H; apply H0. Qed.

  Program Definition wop2 (s:IOS O2) : Wun (IOAr I2 s) :=
    match s with
    | Read _ => ⦑fun p h => forall i, p i ⟨ nfst h, inl i :: nsnd h ⟩⦒
    | Write o => ⦑fun p h => p tt ⟨ nfst h, inr o :: nsnd h ⟩⦒
    end.
  Next Obligation. move=> ? ? H ? H0 ?; apply H ; apply H0. Qed.
  Next Obligation. move=> ? ? H ? H0 ; apply H; apply H0. Qed.

  Import FunctionalExtensionality.
  Lemma io1_io2_commutation : forall s1 s2, commute (wop1 s1) (wop2 s2).
  Proof.
    move=> [|o1] [|o2] //=.
    cbv; apply Ssig_eq=> /=; extensionality k; extensionality h.
    apply SPropAxioms.sprop_ext; do 2 split; done.
  Qed.

  Let Wrel := Wrel Wun.

  Definition θIO :=
    commute_effObs Wun M1 M2 _ _
                   (fromFreeCommute Wun wop1 wop2 io1_io2_commutation).

  Notation "⊨ c1 ≈ c2 [{ w }]" := (semantic_judgement _ _ _ θIO _ _ c1 c2 w).

  Program Definition fromPrePost {A1 A2}
          (pre : Es1 -> Es2 -> SProp)
          (post : A1 -> Es1 -> Es1 -> A2 -> Es2 -> Es2 -> SProp)
    : dfst (Wrel ⟨A1,A2⟩) :=
    ⦑fun p h => pre (nfst h) (nsnd h) s/\
                 forall a1 a2 h', post a1 (nfst h) (nfst h') a2 (nsnd h) (nsnd h')
                            -> p ⟨a1, a2⟩ h'⦒.
  Next Obligation. split; case: H0 => // ? Hy *; apply H, Hy=> //. Qed.

  Notation "⊨ ⦃ pre ⦄ c1 ≈ c2 ⦃ post ⦄" :=
    (semantic_judgement _ _ _ θIO _ _ c1 c2 (fromPrePost pre post)).

  Let read1 := read I1 O1.
  Let write1 := @write I1 O1.
  Let read2 := read I2 O2.
  Let write2 := @write I2 O2.

  Let ttrue : Es1 -> Es2 -> SProp := fun _ _ => sUnit.

  Lemma read1_rule {A2} : forall (a2:A2),
      ⊨ ⦃ ttrue ⦄
        read1 ≈ ret a2
        ⦃ fun i1 h1 h1' a2' h2 h2' =>
            h1' ≡ inl i1 :: h1 s/\ a2' ≡ a2 s/\ h2' ≡ h2 ⦄.
  Proof. cbv; move=> ? ? ? [_ Hpost] ?; by apply: Hpost. Qed.

  Lemma read2_rule {A1} : forall (a1:A1),
      ⊨ ⦃ ttrue ⦄
        ret a1 ≈ read2
        ⦃ fun a1' h1 h1' i2 h2 h2' =>
            h1' ≡  h1 s/\ a1' ≡ a1 s/\ h2' ≡ inl i2 :: h2 ⦄.
  Proof. cbv; move=> ? ? ? [_ Hpost] ?; by apply: Hpost. Qed.

  Lemma write1_rule {A2}: forall (o1 : O1) (a2:A2),
      ⊨ ⦃ ttrue ⦄
        write1 o1 ≈ ret a2
        ⦃ fun _ h1 h1' a2' h2 h2' =>
            h1' ≡ inr o1 :: h1 s/\ a2' ≡ a2 s/\ h2' ≡ h2 ⦄.
  Proof. cbv; move=> ? ? ? ? [_ Hpost] ; by apply: Hpost. Qed.

  Lemma write2_rule {A1}: forall (a1 : A1) (o2:O2),
      ⊨ ⦃ ttrue ⦄
        ret a1 ≈ write2 o2
        ⦃ fun a1' h1 h1' _ h2 h2' =>
            h1' ≡ h1 s/\ a1' ≡ a1 s/\ h2' ≡ inr o2 :: h2 ⦄.
  Proof. cbv; move=> ? ? ? ? [_ Hpost] ; by apply: Hpost. Qed.
End IOs.

Section NI_IO.
  Section IOHigh.
    Context {IPub IPriv Oup : Type}.

    Inductive IOS : Type := ReadLow : IOS | ReadHigh : IOS | Write : Oup -> IOS.
    Definition IOAr (op : IOS) : Type :=
      match op with
      | ReadLow => IPub
      | ReadHigh => IPriv
      | Write _ => unit
      end.

    Definition IO := @Free IOS IOAr.

    Definition readLow : IO IPub := op _ ReadLow.
    Definition readHigh : IO IPriv := op _ ReadHigh.
    Definition write (o:Oup) : IO unit := op _ (Write o).

    Inductive IOTriple : Type := InpPub : IPub -> IOTriple
                               | InpPriv : IPriv -> IOTriple
                               | Out : Oup -> IOTriple.
  End IOHigh.

  Context {IPub1 IPriv1 O1 IPub2 IPriv2 O2 : Type}.
  Notation "i1 ⊕ i2 ⊕ o" := (@IOTriple i1 i2 o) (at level 65, i2 at next level).

  Let Es1 := list (IPub1 ⊕ IPriv1 ⊕ O1).
  Let Es2 := list (IPub2 ⊕ IPriv2 ⊕ O2).
  Let Es12 := Es1 × Es2.
  Let carrier := Es12 -> SProp.

  Definition Wun' :=
    @MonoCont carrier (@Pred_op_order _) (@Pred_op_order_prorder _).

  Program Definition wop1' (s:IOS) : Wun' (IOAr s) :=
    match s with
    | ReadLow => ⦑fun p h => forall i, p i ⟨ InpPub i :: nfst h, nsnd h ⟩⦒
    | ReadHigh => ⦑fun p h => forall i, p i ⟨ InpPriv i :: nfst h, nsnd h ⟩⦒
    | Write o => ⦑fun p h => p tt ⟨ Out o :: nfst h, nsnd h ⟩⦒
    end.
  Next Obligation. move=> ? ? H ? H0 ?; apply H ; apply H0. Qed.
  Next Obligation. move=> ? ? H ? H0 ?; apply H ; apply H0. Qed.
  Next Obligation. move=> ? ? H ? H0 ; apply H; apply H0. Qed.

  Program Definition wop2' (s:IOS) : Wun' (IOAr s) :=
    match s with
    | ReadLow => ⦑fun p h => forall i, p i ⟨ nfst h, InpPub i :: nsnd h ⟩⦒
    | ReadHigh => ⦑fun p h => forall i, p i ⟨ nfst h, InpPriv i :: nsnd h ⟩⦒
    | Write o => ⦑fun p h => p tt ⟨ nfst h, Out o :: nsnd h ⟩⦒
    end.
  Next Obligation. move=> ? ? H ? H0 ?; apply H ; apply H0. Qed.
  Next Obligation. move=> ? ? H ? H0 ?; apply H ; apply H0. Qed.
  Next Obligation. move=> ? ? H ? H0 ; apply H; apply H0. Qed.

  Lemma io1_io2_commutation' : forall s1 s2, commute (wop1' s1) (wop2' s2).
  Proof.
    move=> [||o1] [||o2] //=.
    all: cbv; apply Ssig_eq=> /=; extensionality k; extensionality h.
    all: apply SPropAxioms.sprop_ext; do 2 split => //.
  Qed.

  Let M1 := @IO IPub1 IPriv1 O1.
  Let M2 := @IO IPub2 IPriv2 O2.
  Let Wrel := Wrel Wun'.

  Definition θIO' :=
    commute_effObs Wun' M1 M2 _ _
                   (fromFreeCommute Wun' wop1' wop2' io1_io2_commutation').

  Program Definition fromPrePost' {A1 A2}
          (pre : Es1 -> Es2 -> SProp)
          (post : A1 -> Es1 -> Es1 -> A2 -> Es2 -> Es2 -> SProp)
    : dfst (Wrel ⟨A1,A2⟩) :=
    ⦑fun p h => pre (nfst h) (nsnd h) s/\
                 forall a1 a2 h', post a1 (nfst h) (nfst h') a2 (nsnd h) (nsnd h')
                            -> p ⟨a1, a2⟩ h'⦒.
  Next Obligation. split; case: H0 => // ? Hy *; apply H, Hy=> //. Qed.
End NI_IO.

Section NI_Examples.
  (* For the purpose of examples, let's just have one type of inputs and outputs *)
  Context (Ty : Type).
  Let θIO' := @θIO' Ty Ty Ty Ty Ty Ty.
  Let Wun' := @Wun' Ty Ty Ty Ty Ty Ty.
  Let readHigh := @readHigh Ty Ty Ty.
  Let readLow := @readLow Ty Ty Ty.
  Let write := @write Ty Ty Ty.
  Let IOTriple := @IOTriple Ty Ty Ty.

  Notation "⊨ ⦃ pre ⦄ c1 ≈ c2 ⦃ post ⦄" :=
    (semantic_judgement _ _ _ θIO' _ _ c1 c2 (fromPrePost' pre post)).

  Definition isPubInp (i : IOTriple) : bool := match i with
                                           | InpPub _ => true
                                           | _ => false
                                           end.

  Definition isPrivInp (i : IOTriple) : bool := match i with
                                            | InpPriv _ => true
                                            | _ => false
                                            end.

  Definition isOut (i : IOTriple) : bool := match i with
                                        | Out _ => true
                                        | _ => false
                                        end.

  (* Noninterference property *)
  Definition NI {A : Type} (c : IO A) :=
    ⊨ ⦃ fun h1 h2 => filter isPubInp h1 ≡ filter isPubInp h2 ⦄
      c ≈ c
      ⦃ fun a1 h1 h1' a2 h2 h2' => h1' ≡ h2' s/\ a1 ≡ a2 ⦄.

  Let prog1 := bind readHigh write.
End NI_Examples.
