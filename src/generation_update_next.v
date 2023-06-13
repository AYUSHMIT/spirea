From Equations Require Import Equations.

From iris.algebra Require Import functions gmap agree excl csum max_prefix_list.
From iris.algebra.lib Require Import mono_list.
From iris.proofmode Require Import classes tactics.
From iris.base_logic.lib Require Export iprop own invariants.
From iris.prelude Require Import options.

From iris_named_props Require Import named_props.

From self Require Import hvec extra basic_nextgen_modality gen_trans
  gen_single_shot gen_pv.
From self.high Require Import increasing_map.

Import EqNotations. (* Get the [rew] notation. *)
Import uPred.

#[global] Instance eqdecision_eqdec a : EqDecision a → EqDec a.
Proof. done. Qed.

(** A copy of [option] to work arround universe inconsistencies that arrise if
we use [option]. *)
(* Inductive option2 (A : Type) : Type := *)
(*   | Some2 : A -> option2 A *)
(*   | None2 : option2 A. *)

(* Arguments Some2 {A} a. *)
(* Arguments None2 {A}. *)

(*
Inductive list2 (A : Type) : Type :=
 | nil2 : list2 A
 | cons2 : A -> list2 A -> list2 A.

Arguments nil2 {A}.
Arguments cons2 {A} a l.

Fixpoint list2_lookup {A} (l : list2 A) (n : nat) : option2 A :=
  match n, l with
    | O, cons2 x _ => Some2 x
    | S n, cons2 _ l => list2_lookup l n
    | _, _ => None2
  end.

Local Infix "!!2" := list2_lookup (at level 50, left associativity).
 *)

(* NOTE: Some terminology used in this module.
 *
 * If [A] is a camera a _transformation_ for [A] is a function of type [A → A].
 *
 * A _predicate_ is a unary-predicate over a transformation for [A] with type
 * [(A → A) → Prop].
 *
 * A _relation_ is an n-ary predicate over transformation for a list of cameras
 * [DS] and a camera [A]. I.e., with the type [(DS_0 → DS_0) → ... (DS_n →
 * DS_n) → (A → A) → Prop].
 *
 * Note that we use "predicate" to mean "unary-predicate" and "relation" to
 * mean "n-aray" predicate where n > 1.
 *)

Section types.

  (** A transformation over the carrier of the camera [A]. *)
  Definition cmra_to_trans A := cmra_car A → cmra_car A.

  (** A predicate over a transformation over [A]. *)
  Definition pred_over A := (cmra_to_trans A) → Prop.

  (** Relation that is always true. *)
  Definition True_pred {A} : pred_over A := λ _, True.

  (* Definition rel_over_typ {n} (DS : ivec n Type) (A : Type) := *)
  (*   iimpl id ((λ a, a → a) <$> DS) ((A → A) → Prop). *)

  (* (* An example to demonstrate [rel_over_typ]. This results in the type: *)
  (*    [(bool → bool) → (() → ()) → (nat → nat) → Prop] *) *)
  (* Compute (rel_over_typ [bool : Type; unit : Type] nat). *)

  (** A relation over transformations between the cameras in [DS and [A]. *)
  Definition rel_over {n} (DS : ivec n cmra) (A : cmra) :=
    iimpl (cmra_to_trans <$> DS) ((A → A) → Prop).

  (* An example to demonstrate [rel_over]. This results in the type:
     [(max_nat → max_nat) → (excl () → excl ()) → (nat → nat) → Prop] *)
  Compute (rel_over [max_natR; exclR unitO] natR).

  (** Relation that is always true. *)
  Definition True_rel {n} {DS : ivec n cmra} {A} : rel_over DS A :=
    hcurry (λ _ _, True).

  Definition trans_for n (DS : ivec n cmra) := hvec n (cmra_to_trans <$> DS).

  (* Test that [trans_for] does not give universe issue. *)
  #[local]
  Definition test_exist {Σ} {n : nat} {DS : ivec n cmra} : iProp Σ :=
    ∃ (ts : trans_for n DS), ⌜ True ⌝.

  (* Notation trans_for_old := (hvec cmra_to_trans). *)

  (* trans_for_old _does_ give universe issue. The root cause is the way the
   * [cmra] appears in the type. In [trans_for] the occurence of [cmra_car]
   * prevents the universe issue somehow. *)
  (* Definition test_exist {Σ} {n : nat} {DS : ivec cmra n} : iProp Σ := *)
  (*   ∃ (ts : trans_for n DS), ⌜ True ⌝. *)

End types.

Notation preds_for n ls := (hvec n (pred_over <$> ls)).

(* The functor in [Σ] at index [i] applied to [iProp]. *)
Notation R Σ i := (rFunctor_apply (gFunctors_lookup Σ i) (iPropO Σ)).
(* The functor in [Σ] at index [i] applied to [iPreProp]. *)
Notation Rpre Σ i := (rFunctor_apply (gFunctors_lookup Σ i) (iPrePropO Σ)).
Notation T Σ i := (R Σ i → R Σ i).

Local Definition map_unfold {Σ} {i : gid Σ} : R Σ i -n> Rpre Σ i :=
  rFunctor_map _ (iProp_fold, iProp_unfold).
Local Definition map_fold {Σ} {i : gid Σ} : Rpre Σ i -n> R Σ i :=
  rFunctor_map _ (iProp_unfold, iProp_fold).

Lemma map_unfold_inG_unfold {Σ A} {i : inG Σ A} :
  map_unfold ≡ own.inG_unfold (i := i).
Proof. done. Qed.

Lemma map_fold_unfold {Σ} {i : gid Σ} (a : R Σ i) :
  map_fold (map_unfold a) ≡ a.
Proof.
  rewrite /map_fold /map_unfold -rFunctor_map_compose -{2}[a]rFunctor_map_id.
  apply (ne_proper (rFunctor_map _)); split=> ?; apply iProp_fold_unfold.
Qed.

Lemma map_unfold_op {Σ} {i : gid Σ} (a b : R Σ i)  :
  map_unfold a ⋅ map_unfold b ≡ map_unfold (a ⋅ b).
Proof. rewrite cmra_morphism_op. done. Qed.

Lemma map_unfold_validN {Σ} {i : gid Σ} n (x : R Σ i) :
  ✓{n} (map_unfold x) ↔ ✓{n} x.
Proof.
  split; [|apply (cmra_morphism_validN _)].
  move=> /(cmra_morphism_validN map_fold). by rewrite map_fold_unfold.
Qed.

Lemma map_unfold_validI {Σ} {i : gid Σ} (a : R Σ i) :
  ✓ map_unfold a ⊢@{iPropI Σ} ✓ a.
Proof. apply valid_entails=> n. apply map_unfold_validN. Qed.

(** Transport an endo map on a camera along an equality in the camera. *)
Definition cmra_map_transport {A B : cmra}
    (Heq : A = B) (f : A → A) : (B → B) :=
  eq_rect A (λ T, T → T) f _ Heq.

Section cmra_map_transport.
  Context {A B : cmra} (eq : A = B).

  #[global]
  Instance cmra_map_transport_ne' f :
    NonExpansive f →
    NonExpansive (cmra_map_transport (A := A) (B := B) eq f).
  Proof. solve_proper. Qed.

  Lemma cmra_map_transport_cmra_transport
      (f : A → A) a :
    (cmra_map_transport eq f) (cmra_transport eq a) =
    (cmra_transport eq (f a)).
  Proof. destruct eq. simpl. reflexivity. Defined.

  Global Instance cmra_map_transport_proper (f : A → A) :
    (Proper ((≡) ==> (≡)) f) →
    (Proper ((≡) ==> (≡)) (cmra_map_transport eq f)).
  Proof. naive_solver. Qed.

  Lemma cmra_map_transport_op f `{!GenTrans f} x y :
    cmra_map_transport eq f (x ⋅ y) ≡
      cmra_map_transport eq f x ⋅ cmra_map_transport eq f y.
  Proof. destruct eq. simpl. apply: generation_op. Qed.

  (* Lemma cmra_map_transport_core x : T (core x) = core (T x). *)
  (* Proof. by destruct H. Qed. *)

  Lemma cmra_map_transport_validN n f `{!GenTrans f} a :
    ✓{n} a → ✓{n} cmra_map_transport eq f a.
  Proof. destruct eq. apply generation_valid. Qed.

  Lemma cmra_map_transport_pcore f `{!GenTrans f} x :
    cmra_map_transport eq f <$> pcore x ≡ pcore (cmra_map_transport eq f x).
  Proof. destruct eq. simpl. apply generation_pcore. Qed.

End cmra_map_transport.

(* Resources for generational ghost state. *)

(* Resource algebra for the dependency relation in promises. *)
(* Q: Do we need to store both R and P or only R?? *)
Section dependency_relation_cmra.
  Context {n : nat}.

  Canonical Structure pred_overO (A : cmra) :=
    leibnizO (pred_over A).
  Canonical Structure rel_overO (DS : ivec n cmra) (A : cmra) :=
    leibnizO (rel_over DS A).

End dependency_relation_cmra.

(** The transformations [ts] satisfies the predicates [ps]. *)
Equations preds_hold {n} {DS : ivec n cmra}
    (ps : preds_for n DS) (ts : trans_for n DS) : Prop :=
  @preds_hold _ (icons _ DS') (hcons p ps') (hcons t ts') := p t ∧ preds_hold ps' ts';
  @preds_hold _ (inil) hnil hnil := True.
Global Transparent preds_hold.

Lemma preds_hold_alt {n DS} (ps : preds_for n DS) (ts : trans_for n DS) :
  preds_hold ps ts ↔ ∀ (i : fin n), (hvec_lookup_fmap ps i) (hvec_lookup_fmap ts i).
Proof.
  split.
  - intros holds i.
    induction i as [?|?? IH] eqn:eq.
    * dependent elimination DS.
      dependent elimination ts.
      dependent elimination ps.
      destruct holds as [pred ?].
      apply pred.
    * dependent elimination DS.
      dependent elimination ts.
      dependent elimination ps.
      rewrite preds_hold_equation_2 in holds.
      destruct holds as [? holds].
      apply (IH  _ _ _ holds t).
      done.
  - intros i.
    induction DS as [|??? IH].
    * dependent elimination ts.
      dependent elimination ps.
      done.
    * dependent elimination ts.
      dependent elimination ps.
      rewrite preds_hold_equation_2.
      split. { apply (i 0%fin). }
      apply IH.
      intros i'.
      apply (i (FS i')).
Qed.

Section dependency_relation_extra.
  Context {n} {A : cmra} {DS : ivec n cmra}.
  Implicit Types (R : rel_over DS A) (P : (A → A) → Prop).

  Definition rel_stronger (R1 R2 : rel_over DS A) :=
    ∀ (ts : trans_for n DS) (t : A → A),
      huncurry R1 ts t → huncurry R2 ts t.

  #[global]
  Instance rel_stronger_preorder : PreOrder rel_stronger.
  Proof.
    split.
    - intros ??. naive_solver.
    - intros ???????. naive_solver.
  Qed.

  Definition rel_weaker := flip rel_stronger.

  Lemma rel_weaker_stronger R1 R2 : rel_stronger R1 R2 ↔ rel_weaker R2 R1.
  Proof. done. Qed.

  #[global]
  Instance rel_weaker_preorder : PreOrder rel_weaker.
  Proof. unfold rel_weaker. apply _. Qed.

  Definition pred_stronger (P1 P2 : (A → A) → Prop) :=
    ∀ (t : A → A), P1 t → P2 t.

  #[global]
  Instance pred_stronger_preorder : PreOrder pred_stronger.
  Proof.
    split.
    - intros ??. naive_solver.
    - intros ???????. naive_solver.
  Qed.

  Definition pred_weaker := flip pred_stronger.

  #[global]
  Instance pred_weaker_preorder : PreOrder pred_weaker.
  Proof. unfold pred_weaker. apply _. Qed.

  Lemma pred_weaker_stronger P1 P2 : pred_stronger P1 P2 ↔ pred_weaker P2 P1.
  Proof. done. Qed.

  Lemma pred_stronger_trans (P1 P2 P3 : (A → A) → Prop) :
    pred_stronger P1 P2 → pred_stronger P2 P3 → pred_stronger P1 P3.
  Proof. intros S1 S2 ? ?. apply S2. apply S1. done. Qed.

  Definition rel_implies_pred R P : Prop :=
    ∀ (ts : trans_for n DS) (t : A → A), huncurry R ts t → P t.

  (* Notation preds_for n ls := (hvec pred_over n ls). *)

  (* TODO: Delete this probably. *)
  Definition rel_prefix_list_for {A} rel (all : list A) e :=
    (* The given promise [R] is the last promise out of all promises. *)
    last all = Some e ∧
    (* The list of promises increases in strength. *)
    increasing_list rel all.

  Definition pred_prefix_list_for' (rels : list (rel_over DS A)) preds R P :=
    length rels = length preds ∧
    rel_prefix_list_for rel_weaker rels R ∧
    rel_prefix_list_for pred_weaker preds P ∧
    rel_implies_pred R P.

  Lemma pred_prefix_list_for'_singl R P :
    rel_implies_pred R P →
    pred_prefix_list_for' (R :: []) (P :: []) R P.
  Proof.
    rewrite /pred_prefix_list_for'.
    rewrite /rel_prefix_list_for.
    intros ?. split_and!; eauto using increasing_list_singleton.
  Qed.

  Lemma pred_prefix_list_for'_True :
    pred_prefix_list_for' (True_rel :: []) (True_pred :: []) True_rel True_pred.
  Proof. apply pred_prefix_list_for'_singl. done. Qed.

  Lemma pred_prefix_list_for'_grow rels preds P_1 R_1 R_2 P_2 :
    rel_implies_pred R_2 P_2 →
    rel_weaker R_1 R_2 →
    pred_weaker P_1 P_2 →
    pred_prefix_list_for' rels preds R_1 P_1 →
    pred_prefix_list_for' (rels ++ (R_2 :: nil)) (preds ++ (P_2 :: nil)) R_2 P_2.
  Proof.
    rewrite /pred_prefix_list_for'. rewrite /rel_prefix_list_for.
    rewrite !app_length.
    intros ??? (-> & [??] & [??] & ?).
    rewrite !last_snoc.
    split_and!; try done; eapply increasing_list_snoc; done.
  Qed.

  Lemma pred_prefix_list_for_prefix_of {B} (Rel : relation B) `{!PreOrder Rel}
      (Rs1 Rs2 : list B) e e2:
    rel_prefix_list_for Rel Rs1 e →
    rel_prefix_list_for Rel Rs2 e2 →
    Rs1 `prefix_of` Rs2 →
    Rel e e2.
  Proof.
    intros PP1 PP2 pref.
    destruct PP1 as [isLast1 _].
    destruct PP2 as [isLast2 weaker].
    rewrite last_lookup in isLast1.
    eapply prefix_lookup in isLast1; last done.
    apply: increasing_list_last_greatest; done.
  Qed.

End dependency_relation_extra.

Local Infix "*R*" := prodR (at level 50, left associativity).

Definition generational_cmraR {n} (A : cmra) (DS : ivec n cmra) : cmra :=
  (* Agreement on transformation into generation *)
  optionR (agreeR (leibnizO (A → A))) *R*
  (* Facilitates choice of transformation out of generation *)
  GTSR (A → A) *R*
  (* Ownership over A *)
  optionR A *R*
  (* Gname of dependencies - we don't need to store their [gid] as that is static. *)
  optionR (agreeR (leibnizO (list gname))) *R*
  (* List of promised relations. *)
  gen_pvR (mono_listR (rel_overO DS A)) *R*
  (* List of promised predicates. *)
  gen_pvR (mono_listR (pred_overO A)).

Local Infix "*M*" := prod_map (at level 50, left associativity).

(* The generational transformation function for the encoding of each ownership
over a generational camera. *)
Definition gen_cmra_trans {n} {A : cmra} {DS : ivec n cmra}
    (f : A → A) : generational_cmraR A DS → generational_cmraR A DS :=
  (const (Some (to_agree f)) : _ → optionR (agreeR (leibnizO (A → A)))) *M*
  (GTS_floor : (GTSR (A → A)) → (GTSR (A → A))) *M*
  (fmap f : optionR A → optionR A) *M*
  id *M*
  gen_pv_trans *M*
  gen_pv_trans.

Section tuple_helpers.
  (* Working with the 6-tuple is sometimes annoying. These lemmas help. *)
  Context {A B C D E F : cmra}.
  Implicit Types (a : A) (b : B) (c : C) (d : D) (e : E) (f : F).

  Lemma prod_valid_1st {Σ} a1 b1 c1 d1 e1 f1 a2 b2 c2 d2 e2 f2 :
    ✓ ((a1, b1, c1, d1, e1, f1) ⋅ (a2, b2, c2, d2, e2, f2)) ⊢@{iProp Σ} ✓ (a1 ⋅ a2).
  Proof. rewrite 5!prod_validI /= -4!assoc. iIntros "(? & ? & ? & ? & ? & ?)". done. Qed.

  Lemma prod_valid_2nd {Σ} a1 b1 c1 d1 e1 f1 a2 b2 c2 d2 e2 f2 :
    ✓ ((a1, b1, c1, d1, e1, f1) ⋅ (a2, b2, c2, d2, e2, f2)) ⊢@{iProp Σ} ✓ (b1 ⋅ b2).
  Proof. rewrite 5!prod_validI /= -4!assoc. iIntros "(? & ? & ? & ? & ? & ?)". done. Qed.

  Lemma prod_valid_3th {Σ} a1 b1 c1 d1 e1 f1 a2 b2 c2 d2 e2 f2 :
    ✓ ((a1, b1, c1, d1, e1, f1) ⋅ (a2, b2, c2, d2, e2, f2)) ⊢@{iProp Σ} ✓ (c1 ⋅ c2).
  Proof. rewrite 5!prod_validI /= -4!assoc. iIntros "(? & ? & ? & ? & ? & ?)". done. Qed.

  Lemma prod_valid_4th {Σ} a1 b1 c1 d1 e1 f1 a2 b2 c2 d2 e2 f2 :
    ✓ ((a1, b1, c1, d1, e1, f1) ⋅ (a2, b2, c2, d2, e2, f2)) ⊢@{iProp Σ} ✓ (d1 ⋅ d2).
  Proof. rewrite 5!prod_validI /= -4!assoc. iIntros "(? & ? & ? & ? & ? & ?)". done. Qed.

  Lemma prod_valid_5th {Σ} a1 b1 c1 d1 e1 f1 a2 b2 c2 d2 e2 f2 :
    ✓ ((a1, b1, c1, d1, e1, f1) ⋅ (a2, b2, c2, d2, e2, f2)) ⊢@{iProp Σ} ✓ (e1 ⋅ e2).
  Proof. rewrite 5!prod_validI /= -4!assoc. iIntros "(? & ? & ? & ? & ? & ?)". done. Qed.

  Lemma prod_valid_6th {Σ} a1 b1 c1 d1 e1 f1 a2 b2 c2 d2 e2 f2 :
    ✓ ((a1, b1, c1, d1, e1, f1) ⋅ (a2, b2, c2, d2, e2, f2))
    ⊢@{iProp Σ} ✓ (f1 ⋅ f2).
  Proof. rewrite 5!prod_validI /= -4!assoc. iIntros "(? & ? & ? & ? & ? & ?)". done. Qed.

  Lemma prod_6_equiv a1 b1 c1 d1 e1 f1 a2 b2 c2 d2 e2 f2 :
    (a1, b1, c1, d1, e1, f1) ≡ (a2, b2, c2, d2, e2, f2)
    ↔ (a1 ≡ a2) ∧ (b1 ≡ b2) ∧ (c1 ≡ c2) ∧ (d1 ≡ d2) ∧ (e1 ≡ e2) ∧ (f1 ≡ f2).
  Proof.
    split.
    - intros (((((? & ?) & ?) & ?) & ?) & ?). done.
    - intros (? & ? & ? & ? & ? & ?). done.
  Qed.

  Lemma prod_6_equivI {Σ} a1 b1 c1 d1 e1 f1 a2 b2 c2 d2 e2 f2 :
    (a1, b1, c1, d1, e1, f1) ≡ (a2, b2, c2, d2, e2, f2)
    ⊣⊢@{iProp Σ} (a1 ≡ a2) ∧ (b1 ≡ b2) ∧ (c1 ≡ c2) ∧ (d1 ≡ d2) ∧ (e1 ≡ e2) ∧ (f1 ≡ f2).
  Proof. rewrite !prod_equivI. simpl. rewrite -4!assoc. done. Qed.

End tuple_helpers.

(* Constructors for each of the elements in the pair. *)

Definition gc_tup_pick_in {n A} (DS : ivec n cmra) pick_in : generational_cmraR A DS :=
 (Some (to_agree (pick_in)), ε, ε, ε, ε, ε).

Definition gc_tup_pick_out {A n} (DS : ivec n cmra) pick_out : generational_cmraR A DS :=
 (ε, pick_out, ε, ε, ε, ε).

Definition gc_tup_elem {A n} (DS : ivec n cmra) a : generational_cmraR A DS :=
 (ε, ε, Some a, ε, ε, ε).

Definition gc_tup_deps {n} A (DS : ivec n cmra) deps : generational_cmraR A DS :=
 (ε, ε, ε, Some (to_agree deps), ε, ε).

Definition gc_tup_promise_list {n A} {DS : ivec n cmra} l : generational_cmraR A DS :=
 (ε, ε, ε, ε, l, ε).

Definition gc_tup_rel_pred {n A} {DS : ivec n cmra} l1 l2 : generational_cmraR A DS :=
 (ε, ε, ε, ε, l1, l2).

Global Instance gen_trans_const {A : ofe} (a : A) :
  GenTrans (const (Some (to_agree a))).
Proof.
  split; first apply _.
  - done.
  - intros. simpl. rewrite (core_id). done.
  - intros ??. simpl.
    rewrite -Some_op.
    rewrite agree_idemp.
    done.
Qed.

Section gen_cmra.
  Context {n} {A : cmra} {DS : ivec n cmra}.
  Global Instance gen_generation_gen_trans (f : A → A)
    `{!Proper (equiv ==> equiv) f} :
    GenTrans f → GenTrans (gen_cmra_trans (DS := DS) f).
  Proof. apply _. Qed.

  Global Instance gen_generation_proper (f : A → A) :
    Proper ((≡) ==> (≡)) f →
    Proper ((≡) ==> (≡)) (gen_cmra_trans (DS := DS) f).
  Proof.
    intros ? [[??]?] [[??]?] [[??]?]. simpl in *.
    rewrite /gen_cmra_trans.
    solve_proper.
  Qed.

  Global Instance gen_generation_ne (f : A → A) :
    NonExpansive f →
    NonExpansive (gen_cmra_trans (DS := DS) f).
  Proof. solve_proper. Qed.

  Lemma gen_cmra_trans_apply f (a : generational_cmraR A DS) :
    (gen_cmra_trans f) a =
      (Some (to_agree f), GTS_floor a.1.1.1.1.2, f <$> a.1.1.1.2, a.1.1.2,
        gen_pv_trans a.1.2, gen_pv_trans a.2).
  Proof. done. Qed.

End gen_cmra.

(** For every entry in [Ω] we store this record of information. The equality
 * [gcd_cmra_eq] is the "canonical" equality we will use to show that the resource
 * [R Σ i] has the proper form. Using this equality is necesarry as we
 * otherwise end up with different equalities of this form that we then do not
 * know to be equal. *)
Record gen_cmra_data (Σ : gFunctors) len := {
  gcd_cmra : cmra;
  gcd_n : nat;
  gcd_deps : ivec gcd_n cmra;
  gcd_deps_ids : ivec gcd_n (fin len);
  gcd_gid : gid Σ;
  gcd_cmra_eq : generational_cmraR gcd_cmra gcd_deps = R Σ gcd_gid;
}.

Arguments gcd_cmra {_} {_}.
Arguments gcd_n {_} {_}.
Arguments gcd_deps {_} {_}.
Arguments gcd_deps_ids {_} {_}.
Arguments gcd_gid {_} {_}.
Arguments gcd_cmra_eq {_} {_}.

Definition gen_cmra_data_to_inG {Σ len} (gcd : gen_cmra_data Σ len) :
    inG Σ (generational_cmraR gcd.(gcd_cmra) gcd.(gcd_deps)).
Proof. econstructor. apply gcd_cmra_eq. Defined.

Definition gen_cmras_data Σ len := ∀ (i : fin len), gen_cmra_data Σ len.

(* Each entry in [gen_cmras_data] contain a list of cameras that should be the
 * cmras of the dependencies. This duplicated information in the sense that the
 * cmras of the dependencies is also stored at their indices. We say that a
 * [gen_cmras_data] is _well-formed_ if this duplicated information is equal.
 * *)

(* [map] is well-formed at the index [id]. *)
Definition omega_wf_at {Σ len} (map : gen_cmras_data Σ len) id : Prop :=
  let gcd := map id in
  ∀ idx,
    let id2 := gcd.(gcd_deps_ids) !!! idx in
    (map id2).(gcd_cmra) = gcd.(gcd_deps) !!! idx.

(** [map] is well-formed at all indices. *)
Definition omega_wf {Σ len} (map : gen_cmras_data Σ len) : Prop :=
  ∀ id, omega_wf_at map id.

(** [gGenCmras] contains a partial map from the type of cameras into a "set"
of valid transformation function for that camera. *)
Class gGenCmras (Σ : gFunctors) := {
  gc_len : nat;
  gc_map : gen_cmras_data Σ gc_len;
  (* Storing this wf-ness criteria for the whole map may be too strong. If this
  * gives problems we can wiggle this requirement around to somewhere else. *)
  gc_map_wf : omega_wf gc_map;
  gc_map_gid : ∀ i1 i2, i1 ≠ i2 → (gc_map i1).(gcd_gid) ≠ (gc_map i2).(gcd_gid);
}.

Definition ggid {Σ} (Ω : gGenCmras Σ) := fin gc_len.

Global Arguments gc_map {_} _.

#[export] Hint Mode gGenCmras +.

(*** Omega helpers *)

(* Various helpers to lookup values in [Ω]. These are defined using notation as
 * Coq is otherwise sometimes not able to figure out when things type-check. *)

(** Lookup the camera in [Ω] at the index [i] *)
Notation Oc Ω i := (Ω.(gc_map) i).(gcd_cmra).

(** Lookup the number of depenencies in [Ω] at the index [i] *)
Notation On Ω i := (Ω.(gc_map) i).(gcd_n).

Definition Ogid {Σ} (Ω : gGenCmras Σ) (i : ggid Ω) : gid Σ :=
  (Ω.(gc_map) i).(gcd_gid).

Instance Ogid_inj {Σ} (Ω : gGenCmras Σ) : Inj eq eq (Ogid Ω).
Proof.
  intros j1 j2 eq.
  destruct (decide (j1 = j2)); first done.
  exfalso. apply: gc_map_gid; done.
Qed.

(** Lookup the dependency cameras in [Ω] at the index [i] *)
Definition Ocs {Σ} (Ω : gGenCmras Σ) (i : ggid Ω) : ivec (On Ω i) cmra :=
  (Ω.(gc_map) i).(gcd_deps).

(* The remaining helpers are not defined using notation as that has not been needed. *)

Lemma generational_cmraR_transp {A1 A2 n1 n2} {DS1 : ivec n1 cmra} {DS2 : ivec n2 cmra}
    (eq_n : n1 = n2) :
  A1 = A2 →
  DS1 = rew <- eq_n in DS2 →
  generational_cmraR A1 DS1 = generational_cmraR A2 DS2.
Proof. revert eq_n. intros -> -> ->. done. Defined.

Lemma generational_cmraR_transp_refl {A n} {DS : ivec n cmra} :
  generational_cmraR_transp (A1 := A) (n1 := n) (DS1 := DS)
    eq_refl eq_refl eq_refl = eq_refl.
Proof. done. Qed.

Section omega_helpers.
  Context {Σ : gFunctors}.
  Implicit Types (Ω : gGenCmras Σ).

  (** Lookup the number of depenencies in [Ω] at the index [i] *)
  Definition Oids Ω i : ivec (On Ω i) (ggid Ω) :=
    (Ω.(gc_map) i).(gcd_deps_ids).

  (** Lookup the dependency cameras in [Ω] at the index [i] *)
  Definition Oeq Ω i : generational_cmraR (Oc Ω i) (Ocs Ω i) = R Σ (Ogid Ω i) :=
    (Ω.(gc_map) i).(gcd_cmra_eq).

  (** This lemma relies on [Ω] being well-formed. *)
  Lemma Ocs_Oids_distr {Ω : gGenCmras Σ}
      id (idx : fin (On Ω id)) (wf : omega_wf_at Ω.(gc_map) id) :
    Ocs Ω id !!! idx = Oc Ω (Oids Ω id !!! idx).
  Proof. rewrite -(wf idx). done. Defined.

End omega_helpers.

(* We define [genInG] which is our generational replacement for [inG]. *)

Class genInG {n} Σ (Ω : gGenCmras Σ) A (DS : ivec n cmra) := GenInG {
  genInG_id : ggid Ω;
  genInG_gcd_n : n = On Ω genInG_id;
  genInG_gti_typ : A = Oc Ω genInG_id;
  genInG_gcd_deps : DS = rew <- [λ n, ivec n _] genInG_gcd_n in
                           (Ω.(gc_map) genInG_id).(gcd_deps);
}.

Global Arguments genInG_id {_} {_} {_} {_} {_} _.

Lemma omega_genInG_cmra_eq {n} {DS : ivec n cmra} `{i : !genInG Σ Ω A DS} :
  generational_cmraR A DS =
  generational_cmraR (Oc Ω (genInG_id i)) (Ocs Ω (genInG_id i)).
Proof.
  apply (generational_cmraR_transp genInG_gcd_n genInG_gti_typ genInG_gcd_deps).
Defined.

(* The regular [inG] class can be derived from [genInG]. *)
Global Instance genInG_inG {n : nat} `{i : !genInG Σ Ω A DS} :
    inG Σ (generational_cmraR A DS) := {|
  inG_id := Ogid Ω (genInG_id (n := n) i);
  inG_prf := eq_trans omega_genInG_cmra_eq (Oeq Ω _);
|}.

(* Knowledge that [A] is a resource, with the information about its dependencies
hidden in the dependent pair. *)
Class genInSelfG (Σ : gFunctors) Ω (A : cmra) := GenInG2 {
  genInSelfG_n : nat;
  genInSelfG_DS : ivec genInSelfG_n cmra;
  genInSelfG_gen : genInG Σ Ω A (genInSelfG_DS);
}.

Arguments genInSelfG_gen {_ _ _} _.
Definition genInSelfG_id `(g : genInSelfG Σ Ω) := genInG_id (genInSelfG_gen g).

Instance genInG_genInSelfG {n} `{i : !genInG Σ Ω A DS} : genInSelfG Σ Ω A := {|
  genInSelfG_n := n;
  genInSelfG_DS := DS;
  genInSelfG_gen := i;
|}.

(** Equality for [On] and [genInG]. *)
Lemma On_genInG {A n} {DS : ivec n cmra} `{i : !genInG Σ Ω A DS} :
  On Ω (genInG_id i) = n.
Proof. symmetry. apply (genInG_gcd_n (genInG := i)). Defined.

(* This class ties together a [genInG] instance for one camera with [genInG]
 * instances for all of its dependencies such that those instances have the
 * right ids as specified in [Ω]. *)
Class genInDepsG {n} (Σ : gFunctors) Ω (A : cmra) (DS : ivec n cmra)
    `{gs : ∀ (i : fin n), genInSelfG Σ Ω (DS !!! i)} := GenDepsInG {
  genInDepsG_gen :> genInG Σ Ω A DS;
  genInDepsG_eqs : ∀ i,
    genInSelfG_id (gs i) = Oids Ω (genInG_id genInDepsG_gen) !!! (rew genInG_gcd_n in i);
}.

Lemma rel_over_eq {n m A1 A2} {DS1 : ivec n cmra} {DS2 : ivec m cmra} (eq : n = m) :
  A1 = A2 →
  DS1 = rew <- eq in DS2 →
  rel_over DS1 A1 = rel_over DS2 A2.
Proof. intros -> ->. destruct eq. done. Defined.

Lemma hvec_eq {n m} (eq : m = n) (DS : ivec n Type) (DS2 : ivec m Type) :
  DS = rew [λ n, ivec n _] eq in DS2 →
  hvec n DS = hvec m DS2.
Proof. destruct eq. intros ->. done. Qed.

Lemma hvec_fmap_eq {n m A} {f : A → Type} (eq : n = m) (DS : ivec n A) (DS2 : ivec m A) :
  DS = rew <- [λ n, ivec n _] eq in DS2 →
  hvec n (f <$> DS) = hvec m (f <$> DS2).
Proof. destruct eq. intros ->. done. Defined.

Section omega_helpers_genInG.
  Context `{Σ : gFunctors, Ω : gGenCmras Σ}.
  Context {A n} {DS : ivec n cmra} {i : genInG Σ Ω A DS}.

  (* When we have a [genInG] instance, that instance mentions some types ([A]
   * and [DS]) that are in fact equal to some of the types in [Ω]. The lemmas
   * in this section establishes these equalities. *)

  (** Equality for [Oc].
   * This equality is used in [build_trans_singleton]. *)
  Lemma Oc_genInG_eq : A = Oc Ω (genInG_id i).
  Proof. apply genInG_gti_typ. Defined.

  Lemma rel_over_Oc_Ocs_genInG :
    rel_over DS A = rel_over (Ocs Ω (genInG_id _)) (Oc Ω (genInG_id _)).
  Proof.
    rewrite /Ocs.
    apply (rel_over_eq genInG_gcd_n genInG_gti_typ genInG_gcd_deps).
  Defined.

  Lemma pred_over_Oc_genInG : pred_over A = pred_over (Oc Ω (genInG_id _)).
  Proof.
    apply (eq_rect _ (λ c, pred_over A = pred_over c) eq_refl _ genInG_gti_typ).
  Defined.

  Lemma trans_for_genInG :
    trans_for n DS = trans_for (On Ω _) (Ocs Ω (genInG_id _)).
  Proof.
    apply (hvec_fmap_eq genInG_gcd_n).
    apply genInG_gcd_deps.
  Defined.

  Lemma preds_for_genInG :
    preds_for n DS = preds_for (On Ω _) (Ocs Ω (genInG_id _)).
  Proof.
    apply (hvec_fmap_eq genInG_gcd_n).
    apply genInG_gcd_deps.
  Defined.

End omega_helpers_genInG.

(*
How to represent the dependencies?

We need
- To be able to store both a collection of ..
  - .. the types of the dependencies [A : Type, ..]
  - .. transformation functions matching the types of the dependencis [t : A → A, ..]
  - .. predicates over the transformation functions.
- We need to be able to map over the types.
- To be able to do an ∧ or a ∗ over the transformation functions.
*)

Definition map_agree_overlap `{FinMap K M} {A} (m1 m2 : M A) :=
  ∀ (k : K) (i j : A), m1 !! k = Some i → m2 !! k = Some j → i = j.

Lemma lookup_union_r_overlap `{FinMap K M} {B} (m1 m2 : M B) γ t :
  map_agree_overlap m1 m2 →
  m2 !! γ = Some t →
  (m1 ∪ m2) !! γ = Some t.
Proof.
  intros lap look.
  destruct (m1 !! γ) eqn:eq.
  - apply lookup_union_Some_l.
    rewrite eq.
    f_equiv.
    eapply lap; done.
  - rewrite -look. apply lookup_union_r. done.
Qed.

Lemma map_union_subseteq_l_overlap `{FinMap K M} {B} (m1 m2 : M B) :
  map_agree_overlap m1 m2 →
  m2 ⊆ m1 ∪ m2.
Proof.
  intros lap.
  apply map_subseteq_spec => i x look.
  apply lookup_union_r_overlap; done.
Qed.

(** A [TransMap] contains transformation functions for a subset of ghost
 * names. We use one to represent the transformations that a user has picked.
 * the entries that we have picked generational transformations for. *)
Notation TransMap := (λ Ω, ∀ i, gmap gname (Oc Ω i → Oc Ω i)).

Section transmap.
  Context `{Σ : gFunctors, Ω : gGenCmras Σ}.

  Implicit Types (transmap : TransMap Ω).

  #[global]
  Instance transmap_subseteq : SubsetEq (TransMap Ω) :=
    λ p1 p2, ∀ i, p1 i ⊆ p2 i.

  #[global]
  Instance transmap_subseteq_reflexive : Reflexive transmap_subseteq.
  Proof. intros ??. done. Qed.

  #[global]
  Instance transmap_subseteq_transitive : Transitive transmap_subseteq.
  Proof. intros ??? H1 H2 ?. etrans. - apply H1. - apply H2. Qed.

  #[global]
  Instance transmap_subseteq_preorder : PreOrder transmap_subseteq.
  Proof. constructor; apply _. Qed.

  #[global]
  Instance transmap_subseteq_antisym : AntiSymm eq transmap_subseteq.
  Proof. intros ?? H1 H2. (* apply function_extensionality. lol jk. *) Abort.

  #[global]
  Instance transmap_union : Union (TransMap Ω) :=
    λ p1 p2 i, p1 i ∪ p2 i.

  Lemma transmap_union_subseteq_l transmap1 transmap2 :
    transmap1 ⊆ transmap1 ∪ transmap2.
  Proof. intros ?. apply map_union_subseteq_l. Qed.

  Lemma transmap_union_subseteq_r transmap1 transmap2 :
    (∀ i, map_agree_overlap (transmap1 i) (transmap2 i)) →
    transmap2 ⊆ transmap1 ∪ transmap2.
  Proof. intros ? i. apply map_union_subseteq_l_overlap. done. Qed.

  (** Every pick in [transmap] is a valid generational transformation and satisfies
  the conditions for that cmra in [Ω]. *)
  Definition transmap_valid transmap :=
    ∀ i γ t, transmap i !! γ = Some t → GenTrans t.

  From stdpp Require Import finite.

  Lemma finite_decidable_sig `{Finite A} (P : A → Prop) `{∀ i, Decision (P i)} :
    {i : A | P i} + {∀ i, ¬ P i}.
  Proof. destruct (decide (∃ i, P i)) as [?%choice | ?]; naive_solver. Qed.

  Definition Omega_lookup_inverse (j : gid Σ) :
    {i : ggid Ω | Ogid Ω i = j} + {∀ i, Ogid Ω i ≠ j}.
  Proof. apply (finite_decidable_sig (λ i, Ogid Ω i = j)). Qed.

  Lemma Omega_lookup_inverse_eq i j (eq : Ogid Ω i = j) :
    Omega_lookup_inverse j = inleft (exist _ i eq).
  Proof.
    destruct (Omega_lookup_inverse j) as [(?& eq')|oo].
    - f_equiv.
      simplify_eq.
      assert (x = i) as ->.
      { apply Ogid_inj. done. }
      assert (eq' = eq_refl) as ->.
      { rewrite (proof_irrel eq' eq_refl). done. }
      done.
    - exfalso. apply (oo i). done.
  Qed.

  Definition build_trans_at (m : iResUR Σ) (i : ggid Ω)
      (tts : gmap gname (Oc Ω i → Oc Ω i)) : gmapUR gname (Rpre Σ (Ogid Ω i)) :=
    let gccd := Ω.(gc_map) i in
    map_imap (λ γ (a : Rpre Σ gccd.(gcd_gid)),
      (* If the map of transmap contains a transformation then we apply the
       * transformation otherwise we leave the element unchanged. In all
       * cases we apply something of the form [cmra_map_transport]. *)
      let inner_trans : gccd.(gcd_cmra) → gccd.(gcd_cmra) :=
        default (λ a, a) (tts !! γ) in
      let trans :=
        cmra_map_transport gccd.(gcd_cmra_eq) (gen_cmra_trans inner_trans)
      in Some $ map_unfold $ trans $ map_fold a
    ) (m gccd.(gcd_gid)).

  (** This is a key definition for [TransMap]. It builds a global generational
   * transformation based on the transformations in [transmap]. *)
  Definition build_trans transmap : (iResUR Σ → iResUR Σ) :=
    λ (m : iResUR Σ), λ (j : gid Σ),
      match Omega_lookup_inverse j with
      | inleft (exist _ i eq) =>
        rew [λ a, gmapUR gname (Rpre Σ a)] eq in build_trans_at m i (transmap i)
      | inright _ => m j
      end.

  (* (** This is a key definition for [TransMap]. It builds a global generational *)
  (*  * transformation based on the transformations in [transmap]. *) *)
  (* Definition build_trans transmap : (iResUR Σ → iResUR Σ) := *)
  (*   λ (m : iResUR Σ), λ (i : gid Σ), build_trans_at m i (transmap i). *)

  Lemma core_Some_pcore {A : cmra} (a : A) : core (Some a) = pcore a.
  Proof. done. Qed.

  #[global]
  Lemma build_trans_generation transmap :
    transmap_valid transmap → GenTrans (build_trans transmap).
  Proof.
    simpl in transmap.
    intros transmapGT.
    rewrite /build_trans.
    split.
    - rewrite /Proper.
      intros ??? eq i γ.
      specialize (eq i γ).
  Admitted.
  (*
      rewrite 2!build_trans_at_equation_1.
      rewrite /build_trans_at_clause_1.
      specialize (transmapGT i).
      generalize dependent (transmap i). intros t transmapGT.
      destruct (Ω.(gc_map) i); last apply eq.
      rewrite 2!map_lookup_imap.
      destruct (y i !! γ) as [b|] eqn:look1;
        rewrite look1; rewrite look1 in eq; simpl.
      2: { apply dist_None in eq. rewrite eq. done. }
      apply dist_Some_inv_r' in eq as (a & look2 & eq).
      apply symmetry in eq.
      rewrite look2.
      destruct (t !! γ) eqn:look; simpl.
      2: { solve_proper. }
      apply transmapGT in look as [gt ?].
      solve_proper.
    - intros ?? Hval.
      intros i γ.
      rewrite !build_trans_at_equation_1.
      rewrite /build_trans_at_clause_1.
      specialize (transmapGT i).
      generalize dependent (transmap i). intros t transmapGT.
      destruct (Ω.(gc_map) i); last apply Hval.
      rewrite !map_lookup_imap.
      specialize (Hval i γ).
      destruct (a i !! γ) eqn:eq; rewrite eq /=; last done.
      rewrite eq in Hval.
      apply Some_validN.
      apply: cmra_morphism_validN.
      (* rewrite /cmra_map_transport. *)
      destruct (t !! γ) as [pick|] eqn:eq2.
      * simpl.
        specialize (transmapGT γ pick eq2) as GT.
        apply: cmra_map_transport_validN.
        apply: cmra_morphism_validN.
        apply Hval.
      * simpl.
        apply: cmra_map_transport_validN.
        apply: cmra_morphism_validN.
        apply Hval.
    - move=> m /=.
      rewrite cmra_pcore_core.
      simpl.
      f_equiv.
      intros i γ.
      rewrite lookup_core.
      rewrite !build_trans_at_equation_1.
      rewrite /build_trans_at_clause_1.
      specialize (transmapGT i).
      generalize dependent (transmap i). intros t transmapGT.
      (* generalize dependent t. intros t. *)
      destruct (Ω.(gc_map) i). 2: { rewrite lookup_core. reflexivity. }
      rewrite 2!map_lookup_imap.
      rewrite lookup_core.
      destruct (m i !! γ) as [a|] eqn:look; rewrite look; simpl; last done.
      simpl.
      rewrite 2!core_Some_pcore.
      rewrite -cmra_morphism_pcore.
      destruct (t !! γ) as [pick|] eqn:pickLook; simpl.
      * specialize (transmapGT γ pick pickLook) as ?.
        rewrite -cmra_map_transport_pcore.
        rewrite -cmra_morphism_pcore.
        destruct (pcore a); done.
      * rewrite -cmra_map_transport_pcore.
        rewrite -cmra_morphism_pcore.
        destruct (pcore a); done.
    - intros m1 m2.
      intros i γ.
      rewrite !discrete_fun_lookup_op.
      rewrite !build_trans_at_equation_1.
      rewrite /build_trans_at_clause_1.
      simpl.
      rewrite !discrete_fun_lookup_op.
      specialize (transmapGT i).
      generalize dependent (transmap i). intros t transmapGT.
      destruct (Ω.(gc_map) i); last reflexivity.
      rewrite !map_lookup_imap.
      rewrite 2!lookup_op.
      rewrite !map_lookup_imap.
      destruct (m1 i !! γ) eqn:eq1; destruct (m2 i !! γ) eqn:eq2;
        rewrite eq1 eq2; simpl; try done.
      rewrite -Some_op.
      f_equiv.
      rewrite map_unfold_op.
      f_equiv.
      destruct (t !! γ) as [pick|] eqn:pickLook.
      * specialize (transmapGT γ pick pickLook) as ?.
        rewrite -cmra_map_transport_op.
        f_equiv.
        rewrite -cmra_morphism_op.
        done.
      * simpl.
        rewrite -cmra_map_transport_op.
        f_equiv.
        rewrite -cmra_morphism_op.
        done.
  Qed.
   *)

  Lemma build_trans_at_singleton_neq id1 id2 mm pick :
    id1 ≠ (Ogid Ω id2) →
    build_trans_at (discrete_fun_singleton id1 mm) id2 pick ≡ ε.
  Proof.
    intros neq.
    unfold build_trans_at.
    rewrite discrete_fun_lookup_singleton_ne; last done.
    rewrite map_imap_empty.
    done.
  Qed.

  Lemma build_trans_singleton_alt picks id γ
      (a : generational_cmraR (Oc Ω id) (Ocs Ω id)) eqIn (V : transmap_valid picks) pps :
    Oeq Ω id = eqIn →
    picks id = pps →
    build_trans picks (discrete_fun_singleton (Ogid Ω id) {[
      γ := map_unfold (cmra_transport eqIn a)
      ]}) ≡
      discrete_fun_singleton (Ogid Ω id) {[
        γ := map_unfold (cmra_transport eqIn (gen_cmra_trans
        (default (λ a, a) (picks id !! γ)) a))
      ]}.
  Proof.
    rewrite /build_trans. simpl.
    intros eqLook picksLook j2.
    rewrite /own.iRes_singleton.
    destruct (decide (Ogid Ω id = j2)) as [eq|neq].
    - intros γ2.
      rewrite (Omega_lookup_inverse_eq id _ eq).
      rewrite picksLook /=.
      unfold build_trans_at.
      rewrite <- eq.
      rewrite 2!discrete_fun_lookup_singleton.
      destruct eq. simpl.
      rewrite map_lookup_imap.
      destruct (decide (γ = γ2)) as [<- | neqγ].
      2: { rewrite !lookup_singleton_ne; done. }
      rewrite 2!lookup_singleton.
      simpl.
      f_equiv.
      f_equiv.
      rewrite -eqLook.
      unfold Oeq.
      rewrite -cmra_map_transport_cmra_transport.
      assert (∃ bingo, pps !! γ = bingo ∧ (bingo = None ∨ (∃ t, bingo = Some t ∧ GenTrans t)))
          as (mt & ppsLook & disj).
      { exists (pps !! γ).
        split; first done.
        destruct (pps !! γ) eqn:ppsLook. 2: { left. done. }
        right. eexists _. split; try done.
        eapply V. rewrite picksLook. done. }
      rewrite ppsLook. simpl.
      destruct disj as [-> | (t & -> & GT)].
      + simpl. rewrite map_fold_unfold. done.
      + simpl. rewrite map_fold_unfold. done.
    - simpl.
      rewrite discrete_fun_lookup_singleton_ne; last done.
      rewrite discrete_fun_lookup_singleton_ne; last done.
      destruct (Omega_lookup_inverse j2) as [[? eq]|]; last done.
      destruct eq. simpl.
      apply build_trans_at_singleton_neq.
      done.
  Qed.

  Lemma build_trans_singleton {A n} (DS : ivec n cmra) {i : genInG Σ Ω A DS}
        (γ : gname) picks a pps (V : transmap_valid picks) :
    picks (genInG_id i) = pps →
    build_trans picks (own.iRes_singleton γ (a : generational_cmraR A DS)) ≡
      own.iRes_singleton γ (
        gen_cmra_trans (cmra_map_transport (eq_sym genInG_gti_typ) (default (λ a, a) (pps !! γ))) a
      ).
  Proof.
    (* rewrite /build_trans. simpl. *)
    intros picksLook j2.
    (* rewrite /own.iRes_singleton. *)

    (* TODO: Prove this lemma using the lemma above *)
    (* rewrite /own.inG_unfold. *)
    (* fold (@map_unfold Σ (inG_id genInG_inG)). *)
    (* rewrite (build_trans_singleton_alt picks). *)

    rewrite /build_trans. simpl.
    rewrite /own.iRes_singleton.
    destruct (decide (Ogid Ω (genInG_id i) = j2)) as [eq|neq].
    - intros γ2.
      rewrite (Omega_lookup_inverse_eq _ _ eq).
      rewrite picksLook /=.
      unfold build_trans_at.
      rewrite <- eq.
      rewrite 2!discrete_fun_lookup_singleton.
      destruct eq. simpl.
      rewrite map_lookup_imap.
      destruct (decide (γ = γ2)) as [<- | neqγ].
      2: { rewrite !lookup_singleton_ne; done. }
      rewrite 2!lookup_singleton.
      simpl.
      f_equiv.
      f_equiv.
      (* rewrite -eqLook. *)
      unfold Oeq.
      rewrite -cmra_map_transport_cmra_transport.
      assert (∃ bingo, pps !! γ = bingo ∧ (bingo = None ∨ (∃ t, bingo = Some t ∧ GenTrans t)))
          as (mt & ppsLook & disj).
      { exists (pps !! γ).
        split; first done.
        destruct (pps !! γ) eqn:ppsLook. 2: { left. done. }
        right. eexists _. split; try done.
        eapply V. rewrite picksLook. done. }
      rewrite ppsLook. simpl.
      rewrite /own.inG_unfold.
      rewrite cmra_map_transport_cmra_transport.
      rewrite /Oc_genInG_eq.
      destruct i. simpl in *. clear -disj.
      unfold genInG_inG. unfold Oeq. unfold Ogid. simpl. unfold Ocs in *.
      unfold omega_genInG_cmra_eq. simpl.
      destruct (gc_map Ω genInG_id0). simpl in *.
      destruct genInG_gcd_n0. simpl.
      destruct genInG_gti_typ0. unfold eq_rect_r in *. simpl in *.
      destruct genInG_gcd_deps0.
      rewrite generational_cmraR_transp_refl.
      rewrite eq_trans_refl_l.
      destruct disj as [-> | (t & -> & GT)].
      + simpl. rewrite map_fold_unfold.
        rewrite cmra_map_transport_cmra_transport.
        done.
      + simpl. rewrite map_fold_unfold.
        rewrite cmra_map_transport_cmra_transport.
        done.
    - simpl.
      rewrite discrete_fun_lookup_singleton_ne; last done.
      rewrite discrete_fun_lookup_singleton_ne; last done.
      destruct (Omega_lookup_inverse j2) as [[? eq]|]; last done.
      destruct eq. simpl.
      apply build_trans_at_singleton_neq.
      done.
  Qed.

  (** A map of picks that for the resource at [idx] and the ghost name [γ] picks
  the generational transformation [t]. *)
  Definition transmap_singleton i (γ : gname)
      (t : Oc Ω i → Oc Ω i) : TransMap Ω :=
    λ j, match decide (i = j) with
           left Heq =>
             (eq_rect _ (λ i, gmap gname (Oc Ω i → _)) {[ γ := t ]} _ Heq)
         | right _ => ∅
         end.

  Definition transmap_singleton_lookup idx γ (f : Oc Ω idx → Oc Ω idx) :
    transmap_singleton idx γ f idx !! γ = Some f.
  Proof.
    rewrite /transmap_singleton.
    case (decide (idx = idx)); last by congruence.
    intros eq'.
    assert (eq' = eq_refl) as ->.
    { rewrite (proof_irrel eq' eq_refl). done. }
    simpl.
    apply lookup_singleton.
  Qed.

  Definition transmap_singleton_dom_index_eq idx γ f :
    dom (transmap_singleton idx γ f idx) = {[ γ ]}.
  Proof.
    rewrite /transmap_singleton.
    case (decide (idx = idx)); last congruence.
    intros [].
    simpl.
    apply dom_singleton_L.
  Qed.

  Definition transmap_singleton_dom_index_neq idx γ f idx' :
    idx ≠ idx' →
    dom (transmap_singleton idx γ f idx') = ∅.
  Proof.
    intros neq.
    rewrite /transmap_singleton.
    case (decide (idx = idx')); first congruence.
    intros ?.
    apply dom_empty_L.
  Qed.

  Definition gen_f_singleton_lookup_Some idx' idx γ γ' f (f' : Oc Ω idx' → _) :
    (transmap_singleton idx γ f) idx' !! γ' = Some f' →
    ∃ (eq : idx' = idx),
      γ = γ' ∧
      f = match eq in (_ = r) return (Oc Ω r → Oc Ω r) with eq_refl => f' end.
  Proof.
    rewrite /transmap_singleton.
    case (decide (idx = idx')); last first.
    { intros ?. rewrite lookup_empty. inversion 1. }
    intros ->.
    simpl.
    intros [-> ->]%lookup_singleton_Some.
    exists eq_refl.
    done.
  Qed.

End transmap.

(* Arguments TransMap {Σ} _. (* : clear implicits. *) *)

(** Inside the model of the [nextgen] modality we need to store a list of all
 * known promises. To this end, [promise_info] is a record of all the
 * information that is associated with a promise. Note that we use
 * [promise_self_info] for the dependencies, this cuts off what would
 * otherwise be an inductive record - simplifying things at the cost of some
 * power.
 *
 * NOTE: We can not store cameras directly in [promise_info] as that leads to
 * universe issues (in particular, any Iris existential quantification over
 * something involing a [cmra] fails. We hence store all cameras in [Ω] and
 * look up into it). *)
Record promise_info_at {Σ} (Ω : gGenCmras Σ) id := MkPia {
  (* We have the generational cmra data for this index, this contains all
   * static info about the promise dependency for this index. *)
  pi_deps_γs : ivec (On Ω id) gname;
  (* Dynamic information that changes per promise *)
  pi_deps_preds : preds_for (On Ω id) (Ocs Ω id);
  (* The predicate that relates our transformation to those of the dependencies. *)
  (* NOTE: Maybe store the rel in curried form? *)
  pi_rel : rel_over (Ocs Ω id) (Oc Ω id);
  (* A predicate that holds for the promise's own transformation whenever
   * [pi_rel] holds. A "canonical" choice could be: [λ t, ∃ ts, pi_rel ts t]. *)
  pi_pred : pred_over (Oc Ω id);
  pi_rel_to_pred : ∀ (ts : trans_for (On Ω id) (Ocs Ω id)) t,
    huncurry pi_rel ts t → pi_pred t;
  pi_witness : ∀ (ts : trans_for (On Ω id) (Ocs Ω id)),
    preds_hold pi_deps_preds ts → ∃ t, huncurry pi_rel ts t;
}.

Record promise_info {Σ} (Ω : gGenCmras Σ) := MkPi {
  (* We need to know the specific ghost location that this promise is about *)
  pi_id : ggid Ω; (* The index of the RA in the global RA *)
  pi_γ : gname; (* Ghost name for the promise *)
  (* With this coercion the inner [promise_info_at] record behaves as if it was
   * included in [promise_info] directly. *)
  pi_at :> promise_info_at Ω pi_id;
}.

(* Check that we can existentially quantify over [promise_info] without
 * universe inconsistencies. *)
#[local] Definition promise_info_universe_test {Σ} {Ω : gGenCmras Σ} : iProp Σ :=
  ∃ (ps : promise_info Ω), True.

Arguments MkPi {_ _}.

Arguments pi_id {_ _}.
Arguments pi_γ {_ _}.
Arguments pi_at {_ _}.

Arguments pi_deps_γs {_ _ _}.
Arguments pi_deps_preds {_ _ _}.
Arguments pi_rel {_ _ _}.
Arguments pi_pred {_ _ _}.
Arguments pi_rel_to_pred {_ _ _}.
Arguments pi_witness {_ _ _}.

(* This lemma combines a use of [hvec_lookup_fmap} and [Ocs_Oids_distr] to
 * ensure that looking up in [cs] results in a useful return type. [f] will
 * usually be [pred_over] or [cmra_to_trans]. *)
Definition lookup_fmap_Ocs `{Ω : gGenCmras Σ} {f id}
    (cs : hvec (On Ω id) (f <$> Ocs Ω id)) i (wf : omega_wf_at Ω.(gc_map) id)
    : f (Oc Ω (Oids Ω id !!! i)) :=
  eq_rect _ _ (hvec_lookup_fmap cs i) _ (Ocs_Oids_distr _ _ wf).

Definition pi_deps_id `{Ω : gGenCmras Σ} pi idx := Oids Ω pi.(pi_id) !!! idx.

Definition pi_deps_pred `{Ω : gGenCmras Σ} pi idx wf :=
  let id := pi_deps_id pi idx in
  lookup_fmap_Ocs pi.(pi_deps_preds) idx wf.

Section promise_info.
  Context `{Ω : gGenCmras Σ}.

  Implicit Types (prs : list (promise_info Ω)).
  Implicit Types (promises : list (promise_info Ω)).
  Implicit Types (pi : promise_info Ω).

  Definition promises_different p1 p2 :=
    p1.(pi_id) ≠ p2.(pi_id) ∨ p1.(pi_γ) ≠ p2.(pi_γ).

  (* Lemmas for [promises_different]. *)
  Lemma promises_different_not_eq pi1 pi2 :
    ¬ (pi1.(pi_id) = pi2.(pi_id) ∧ pi1.(pi_γ) = pi2.(pi_γ)) →
    promises_different pi1 pi2.
  Proof.
    intros n.
    destruct pi1, pi2.
    rewrite /promises_different. simpl.
    destruct (decide (pi_id0 = pi_id1));
      destruct (decide (pi_γ0 = pi_γ1)); naive_solver.
  Qed.

  Lemma promises_different_sym p1 p2 :
    promises_different p1 p2 → promises_different p2 p1.
  Proof. rewrite /promises_different. intros [?|?]; auto using not_eq_sym. Qed.

  Definition res_trans_transport {id1 id2}
      (eq : id1 = id2) (t : R Σ id1 → R Σ id1) : (R Σ id2 → R Σ id2) :=
    eq_rect _ (λ id, _) t _ eq.

  Definition res_pred_transport {id1 id2} (eq : id1 = id2)
      (t : (R Σ id1 → R Σ id1) → Prop) : ((R Σ id2 → R Σ id2) → Prop) :=
    eq_rect _ (λ id, _) t _ eq.

  Definition gcd_transport {id1 id2}
      (eq : id1 = id2) (gcd : gen_cmra_data Σ id1) : gen_cmra_data Σ id2 :=
    eq_rect _ (λ id, _) gcd _ eq.

  (** The promise [pSat] satisfies the dependency at [idx] of [pi]. Note that
   * the predicate in [pi] may not be the same as the one in [pSat]. When we
   * combine lists of promises some promises might be replaced by stronger
   * ones. Hence we only require that the predicate in [pSat] is stronger than
   * the one in [pi]. *)
  Definition promise_satisfy_dep (pi pSat : promise_info Ω) idx wf :=
    let id := Oids Ω pi.(pi_id) !!! idx in
    let pred : pred_over (Oc Ω id) := lookup_fmap_Ocs pi.(pi_deps_preds) idx wf in
    pi.(pi_deps_γs) !!! idx = pSat.(pi_γ) ∧
    ∃ (eq : id = pSat.(pi_id)),
      (* The predicate in [pSat] is stronger than what is stated in [pi] *)
      pred_stronger
        pSat.(pi_pred)
        (rew [λ id, pred_over (Oc Ω id)] eq in pred).

  (** For every dependency in [p] the list [promises] has a sufficient
   * promise. *)
  Definition promises_has_deps pi promises wf :=
    ∀ idx, ∃ pSat, pSat ∈ promises ∧ promise_satisfy_dep pi pSat idx wf.

  (** The promise [p] is well-formed wrt. the list [promises] of promises that
   * preceeded it. *)
  Definition promise_wf pi promises wf : Prop :=
    (∀ p2, p2 ∈ promises → promises_different pi p2) ∧
    promises_has_deps pi promises wf.

  (* This definition has nice computational behavior when applied to a [cons]. *)
  Fixpoint promises_wf (owf : omega_wf (gc_map Ω)) promises : Prop :=
    match promises with
    | nil => True
    | cons p promises' =>
        promise_wf p promises' (owf p.(pi_id)) ∧ promises_wf owf promises'
    end.

  Lemma promises_wf_unique owf prs :
    promises_wf owf prs →
    ∀ pi1 pi2, pi1 ∈ prs → pi2 ∈ prs → pi1 = pi2 ∨ promises_different pi1 pi2.
  Proof.
    induction prs as [| ?? IH].
    { intros ???. inversion 1. }
    intros [wf ?] pi1 pi2. inversion 1; inversion 1; subst; try naive_solver.
    - right. apply wf. done.
    - right. apply promises_different_sym. apply wf. done.
  Qed.

  (* NOTE: Not used, but should be implied by [promises_wf] *)
  Definition promises_unique promises : Prop :=
    ∀ (i j : nat) pi1 pi2, i ≠ j →
      pi1.(pi_id) ≠ pi2.(pi_id) ∨ pi1.(pi_γ) ≠ pi2.(pi_γ).

  Lemma promises_has_deps_cons p prs wf :
    promises_has_deps p prs wf →
    promises_has_deps p (p :: prs) wf.
  Proof.
    intros hasDeps idx.
    destruct (hasDeps idx) as (p2 & ? & ?).
    eauto using elem_of_list_further.
  Qed.

  (* A well formed promise is not equal to any of its dependencies. *)
  Lemma promise_wf_neq_deps p promises wf :
    promise_wf p promises wf →
    ∀ (idx : fin (On Ω p.(pi_id))),
      p.(pi_id) ≠ (pi_deps_id p idx) ∨ p.(pi_γ) ≠ p.(pi_deps_γs) !!! idx.
  Proof.
    intros [uniq hasDeps] idx.
    destruct (hasDeps idx) as (p2 & elem & idEq & γEq & jhhi).
    rewrite /pi_deps_id idEq γEq.
    destruct (uniq _ elem) as [?|?]; auto.
  Qed.

  Lemma promises_well_formed_lookup owf promises (idx : nat) pi :
    promises_wf owf promises →
    promises !! idx = Some pi →
    promises_has_deps pi promises (owf (pi_id pi)). (* We forget the different part for now. *)
  Proof.
    intros WF look.
    revert dependent idx.
    induction promises as [ |?? IH]; first intros ? [=].
    destruct WF as [[? hasDeps] WF'].
    intros [ | idx].
    * simpl. intros [= ->].
      apply promises_has_deps_cons.
      done.
    * intros look.
      intros d.
      destruct (IH WF' idx look d) as (? & ? & ?).
      eauto using elem_of_list_further.
  Qed.

  Lemma promises_well_formed_lookup_index owf prs pi1 i :
    promises_wf owf prs →
    prs !! (length prs - S i) = Some pi1 →
    ∀ (idx : fin (On Ω pi1.(pi_id))),
      ∃ j pi2 wf,
        j < i ∧ prs !! (length prs - S j) = Some pi2 ∧
        promise_satisfy_dep pi1 pi2 idx wf.
  Proof.
    intros wf look idx.
    generalize dependent i.
    induction prs as [|pi prs' IH]; first done.
    simpl. intros i.
    destruct wf as [[? deps] wfr].
    intros look.
    eassert _. { eapply lookup_lt_Some. done. }
    destruct (decide (length prs' ≤ i)).
    * assert (length prs' - i = 0) as eq by lia.
      rewrite eq in look. injection look as [= ->].
      specialize (deps idx) as (pSat & elm & sat).
      apply elem_of_list_lookup_1 in elm as (j' & look).
      exists (length prs' - (S j')), pSat, (owf (pi1.(pi_id))).
      pose proof look as look'.
      apply lookup_lt_Some in look.
      split_and!; last done.
      - lia.
      - replace (length prs' - (length prs' - S j')) with (S j') by lia.
        done.
    * apply not_le in n.
      assert (1 ≤ length prs' - i) as le by lia.
      apply Nat.le_exists_sub in le as (i' & ? & _).
      rewrite (comm (Nat.add)) in H0.
      simpl in H0.
      rewrite H0 in look.
      simpl in look.
      destruct (IH wfr (length prs' - S i')) as (j & ? & ? & ? & ? & ?).
      { replace (length prs' - S (length prs' - S i')) with i' by lia.
        done. }
      eexists j, _, _.
      split_and!; try done; try lia.
      replace (length prs' - j) with (S (length prs' - S j)) by lia.
      done.
  Qed.

  (* For soundness we need to be able to build a map of gts that agree with
   * picks and that satisfy all promises.

     We need to be able to extend picks along a list of promises.

     We must also be able to combine to lists of promises.
  *)

  Lemma path_equal_or_different {n} (id1 id2 : fin n) (γ1 γ2 : gname) :
    id1 = id2 ∧ γ1 = γ2 ∨ (id1 ≠ id2 ∨ γ1 ≠ γ2).
  Proof.
    destruct (decide (id1 = id2)) as [eq|?]; last naive_solver.
    destruct (decide (γ1 = γ2)) as [eq2|?]; last naive_solver.
    left. naive_solver.
  Qed.

  Equations promises_info_update pi id (γ : gname) (pia : promise_info_at _ id) : promise_info Ω :=
  | pi, id, γ, pia with decide (pi.(pi_id) = id), decide (pi.(pi_γ) = γ) => {
    | left eq_refl, left eq_refl => MkPi pi.(pi_id) pi.(pi_γ) pia;
    | _, _ => pi
    }.

  Definition promises_list_update id γ (pia : promise_info_at _ id)
      (prs : list (promise_info Ω)) :=
    (λ pi, promises_info_update pi id γ pia) <$> prs.

  Equations promises_lookup_at promises iid (γ : gname) : option (promise_info_at _ iid) :=
  | [], iid, γ => None
  | p :: ps', iid, γ with decide (p.(pi_id) = iid), decide (p.(pi_γ) = γ) => {
    | left eq_refl, left eq_refl => Some p.(pi_at);
    | left eq_refl, right _ => promises_lookup_at ps' p.(pi_id) γ
    | right _, _ => promises_lookup_at ps' iid γ
  }.

  Lemma promises_lookup_at_cons_neq prs pi id2 γ2 :
    (pi.(pi_id) ≠ id2 ∨ pi.(pi_γ) ≠ γ2) →
    promises_lookup_at (pi :: prs) id2 γ2 =
      promises_lookup_at prs id2 γ2.
  Proof.
    rewrite promises_lookup_at_equation_2.
    rewrite promises_lookup_at_clause_2_equation_1 /=.
    intros [neq|neq];
      destruct (decide (pi.(pi_id) = id2)) as [<-|?]; try done.
    destruct (decide (pi.(pi_γ) = γ2)) as [?|?]; done.
  Qed.

  Lemma promises_lookup_at_cons prs id γ pia :
    promises_lookup_at ((MkPi id γ pia) :: prs) id γ = Some pia.
  Proof.
    rewrite promises_lookup_at_equation_2.
    rewrite promises_lookup_at_clause_2_equation_1 /=.
    destruct (decide (id = id)) as [eq|?]; last done.
    destruct (decide (γ = γ)) as [eq2|?]; last done.
    assert (eq = eq_refl) as ->.
    { rewrite (proof_irrel eq eq_refl). done. }
    assert (eq2 = eq_refl) as ->.
    { rewrite (proof_irrel eq2 eq_refl). done. }
    rewrite promises_lookup_at_clause_2_clause_1_equation_1.
    done.
  Qed.

  Lemma promises_lookup_at_cons_pr prs pi :
    promises_lookup_at (pi :: prs) (pi_id pi) (pi_γ pi) = Some pi.(pi_at).
  Proof. destruct pi. apply promises_lookup_at_cons. Qed.

  Lemma promises_lookup_at_Some promises id γ pia :
    promises_lookup_at promises id γ = Some pia →
    MkPi id γ pia ∈ promises.
  Proof.
    induction promises as [|[id' γ' ?] ? IH]; first by inversion 1.
    destruct (decide (id' = id)) as [->|neq].
    - destruct (decide (γ' = γ)) as [->|neq].
      * rewrite promises_lookup_at_cons.
        simpl.
        intros [= <-].
        apply elem_of_list_here.
      * rewrite promises_lookup_at_cons_neq; last naive_solver.
        intros ?.
        apply elem_of_list_further.
        apply IH. done.
    - rewrite promises_lookup_at_cons_neq; last naive_solver.
      intros ?.
      apply elem_of_list_further.
      apply IH. done.
  Qed.

  Lemma promises_lookup_at_Some_lookup prs id γ pia :
    promises_lookup_at prs id γ = Some pia →
    ∃ i, prs !! i = Some (MkPi id γ pia).
  Proof.
    intros ?%promises_lookup_at_Some. apply elem_of_list_lookup_1. done.
  Qed.

  Lemma promises_lookup_at_cons_Some_inv prs pi id γ pia :
    promises_lookup_at (pi :: prs) id γ = Some pia →
    (∃ (eq : pi.(pi_id) = id), pi.(pi_γ) = γ ∧ (rew eq in pi.(pi_at) = pia)) ∨
    ((pi.(pi_id) ≠ id ∨ pi.(pi_γ) ≠ γ) ∧ promises_lookup_at prs id γ = Some pia).
  Proof.
    rewrite promises_lookup_at_equation_2.
    rewrite promises_lookup_at_clause_2_equation_1 /=.
    destruct (decide (pi.(pi_id) = id)) as [eq|?]; last naive_solver.
    destruct (decide (pi.(pi_γ) = γ)) as [eq2|?]; last naive_solver.
    destruct eq. destruct eq2.
    rewrite promises_lookup_at_clause_2_clause_1_equation_1.
    intros ?. left. exists eq_refl. naive_solver.
  Qed.

  Lemma promises_lookup_at_cons_None prs id γ pi :
    promises_lookup_at (pi :: prs) id γ = None →
    promises_lookup_at prs id γ = None ∧ (pi.(pi_id) ≠ id ∨ pi.(pi_γ) ≠ γ).
  Proof.
    rewrite promises_lookup_at_equation_2.
    rewrite promises_lookup_at_clause_2_equation_1.
    destruct pi as [id' γ' ?].
    destruct (decide (id' = id)) as [->|neq1] eqn:eqI;
      destruct (decide (γ' = γ)) as [->|neq2] eqn:eqG;
      rewrite eqI eqG; naive_solver.
  Qed.

   Lemma promises_lookup_at_None prs pi1 pi2 :
    promises_lookup_at prs pi1.(pi_id) pi1.(pi_γ) = None →
    pi2 ∈ prs →
    promises_different pi1 pi2.
  Proof.
    induction prs as [|?? IH]; first inversion 2.
    intros [eq diff]%promises_lookup_at_cons_None [<-|?]%elem_of_cons.
    - rewrite /promises_different. naive_solver.
    - apply IH; done.
  Qed.

  Lemma promises_info_update_self pi pia :
    promises_info_update pi (pi_id pi) (pi_γ pi) pia =
      MkPi (pi_id pi) (pi_γ pi) pia.
  Proof.
    rewrite promises_info_update_equation_1.
    rewrite promises_info_update_clause_1_equation_1.
    destruct (decide (pi_id pi = pi_id pi)) as [eq1|]; last done.
    destruct (decide (pi_γ pi = pi_γ pi)) as [eq2|]; last done.
    destruct eq2.
    assert (eq1 = eq_refl) as ->.
    { rewrite (proof_irrel eq1 eq_refl). done. }
    rewrite promises_info_update_clause_1_clause_1_equation_1.
    done.
  Qed.

  Lemma promises_info_update_ne pi id γ pia :
    pi_id pi ≠ id ∨ pi_γ pi ≠ γ →
    promises_info_update pi id γ pia = pi.
  Proof.
    intros neq.
    rewrite promises_info_update_equation_1.
    rewrite promises_info_update_clause_1_equation_1.
    destruct (decide (pi_id pi = id)) as [<-|]; last done.
    destruct (decide (pi_γ pi = γ)) as [eq2|]; naive_solver.
  Qed.

  Lemma promises_lookup_update prs id γ pia pia' :
    promises_lookup_at prs id γ = Some pia →
    promises_lookup_at (promises_list_update id γ pia' prs) id γ = Some pia'.
  Proof.
    induction prs as [|pi prs' IH]; first done.
    intros [(<- & <- & eq)|[neq look]]%promises_lookup_at_cons_Some_inv.
    - simpl in *.
      rewrite promises_info_update_self.
      apply promises_lookup_at_cons.
    - simpl.
      rewrite promises_info_update_ne; last done.
      rewrite promises_lookup_at_cons_neq; last done.
      apply IH.
      done.
  Qed.

  Lemma promises_list_update_elem_of pi id γ pia prs :
    pi ∈ promises_list_update id γ pia prs →
    pi ∈ prs ∨ pi = MkPi id γ pia.
  Proof.
    unfold promises_list_update.
    intros (pi' & -> & elm)%elem_of_list_fmap_2.
    rewrite promises_info_update_equation_1.
    rewrite promises_info_update_clause_1_equation_1.
    destruct (decide (pi'.(pi_id) = id)); last naive_solver.
    destruct (decide (pi'.(pi_γ) = γ)); last naive_solver.
    naive_solver.
  Qed.

  Lemma promises_wf_elem_of_head owf id γ pia1 pia2 promises :
    promises_wf owf ({| pi_id := id; pi_γ := γ; pi_at := pia2 |} :: promises) →
    {| pi_id := id; pi_γ := γ; pi_at := pia1 |}
      ∈ {| pi_id := id; pi_γ := γ; pi_at := pia2 |} :: promises →
    pia1 = pia2.
  Proof.
    intros [(diff & ?) ?].
    intros [eq|?]%elem_of_cons.
    - inversion eq. apply inj_right_pair. done.
    - destruct (diff _ H1) as [neq|neq]; simpl in neq; congruence.
  Qed.

  Lemma promises_elem_of owf promises id γ pia :
    promises_wf owf promises →
    MkPi id γ pia ∈ promises →
    promises_lookup_at promises id γ = Some pia.
  Proof.
    intros wf.
    induction promises as [|[id' γ' ?] ? IH]; first by inversion 1.
    rewrite promises_lookup_at_equation_2.
    rewrite promises_lookup_at_clause_2_equation_1.
    simpl.
    destruct (decide (id' = id)) as [->|neq].
    - destruct (decide (γ' = γ)) as [->|neq].
      * simpl.
        intros ?%(promises_wf_elem_of_head owf); [congruence | assumption].
      * rewrite promises_lookup_at_clause_2_clause_1_equation_2.
        simpl.
        intros [?|?]%elem_of_cons; first congruence.
        apply IH; [apply wf | done].
    - rewrite promises_lookup_at_clause_2_clause_1_equation_3.
      intros [?|?]%elem_of_cons; first congruence.
      apply IH; [apply wf | done].
  Qed.

  Lemma promise_lookup_lookup owf prs pi i :
    promises_wf owf prs →
    prs !! i = Some pi →
    promises_lookup_at prs pi.(pi_id) pi.(pi_γ) = Some pi.(pi_at).
  Proof.
    intros wf look.
    eapply promises_elem_of; first done.
    destruct pi.
    eapply elem_of_list_lookup_2.
    apply look.
  Qed.

  Lemma promise_lookup_at_eq owf id γ prs pia pia' :
    promises_wf owf prs →
    promises_lookup_at prs id γ = Some pia →
    promises_lookup_at prs id γ = Some pia' →
    pia = pia'.
  Proof.
    intros wf.
    intros look%promises_lookup_at_Some.
    intros ?%promises_lookup_at_Some.
    eapply promises_wf_unique in look; [ |done|done].
    destruct look as [[=]|HD].
    - apply inj_right_pair. done.
    - unfold promises_different in HD. naive_solver.
  Qed.

  (** [pia1] is a better promise than [pia2]. *)
  Definition promise_stronger {id} (pia1 pia2 : promise_info_at _ id) : Prop :=
    pia1.(pi_deps_γs) = pia2.(pi_deps_γs) ∧
    rel_stronger pia1.(pi_rel) pia2.(pi_rel) ∧
    pred_stronger pia1.(pi_pred) pia2.(pi_pred).

  Lemma promise_stronger_refl {id} (pia : promise_info_at _ id) :
    promise_stronger pia pia.
  Proof. split_and!; first done; intros ?; naive_solver. Qed.

  (** This definition is supposed to encapsulate what ownership over the
   * resources for [prs1] and [prsR] entails. *)
  Definition promises_overlap_pred prs1 prsR : Prop :=
    ∀ id γ p1 p2,
      promises_lookup_at prs1 id γ = Some p1 →
      promises_lookup_at prsR id γ = Some p2 →
      promise_stronger p1 p2 ∨ promise_stronger p2 p1.

  Lemma promises_overlap_pred_sym prsL prsR :
    promises_overlap_pred prsL prsR ↔ promises_overlap_pred prsR prsL.
  Proof.
    unfold promises_overlap_pred.
    split; intros Ha; intros; rewrite comm; naive_solver.
  Qed.

  (* NOTE: We can not merge promises with a definition as we need to rely
   * on evidence that is in [Prop]. *)
  (* Fixpoint merge_promises prs1 prsR := .. *)

  (** For every promise in [prsR] there is a stronger promise in [prs1]. *)
  Definition promise_list_stronger prs1 prsR : Prop :=
    ∀ id γ pia2,
      promises_lookup_at prsR id γ = Some pia2 →
      ∃ pia1,
        promises_lookup_at prs1 id γ = Some pia1 ∧
        promise_stronger pia1 pia2.

  (** For every promise in [prsR] there is a stronger promise in [prs1]. *)
  Definition promise_list_restrict_stronger prs1 prsR (restrict : list (ggid Ω * gname)) : Prop :=
    ∀ id γ pia2,
      (id, γ) ∈ restrict →
      promises_lookup_at prsR id γ = Some pia2 →
      ∃ pia1,
        promises_lookup_at prs1 id γ = Some pia1 ∧
        promise_stronger pia1 pia2.

  (** For every promise in [prsR] and [prsM] the one in [prsM] is stronger. *)
  Definition promise_list_overlap_stronger prsM prsR : Prop :=
    ∀ id γ pia2 pia1,
      promises_lookup_at prsM id γ = Some pia1 →
      promises_lookup_at prsR id γ = Some pia2 →
        promise_stronger pia1 pia2.

  Definition promise_list_promise_stronger id γ pia prs :=
    ∀ pia1,
      promises_lookup_at prs id γ = Some pia1 → promise_stronger pia pia1.

  Lemma elem_of_elem_of_cons {A} x y (xs : list A) :
    x ∈ xs →
    y ∈ (x :: xs) ↔ y ∈ xs.
  Proof. intros elm. rewrite elem_of_cons. naive_solver. Qed.

  Lemma elem_of_cons_ne {A} x y (l : list A) :
    x ≠ y → x ∈ cons y l → x ∈ l.
  Proof. intros neq. inversion 1; try congruence. Qed.

  Lemma promise_list_restrict_stronger_cons id γ prs3 pia3 prs1 restrict :
    promise_list_overlap_stronger prs3 prs1 →
    promises_lookup_at prs3 id γ = Some pia3 →
    promise_list_restrict_stronger prs3 prs1 restrict →
    promise_list_restrict_stronger prs3 prs1 ((id, γ) :: restrict).
  Proof.
    intros lap look3 res id2 γ2 ?.
    destruct (decide ((id2, γ2) = (id, γ))) as [[= -> ->]|neq].
    - intros _ look2. exists pia3. split; first done.
      eapply lap; done.
    - intros elm. apply res.
      eapply elem_of_cons_ne; done.
  Qed.

  Definition promises_is_valid_restricted_merge prsM prs1 prsR restrict :=
    (* [prsM] has no junk, everything in it is "good". *)
    (∀ pi, pi ∈ prsM → (pi ∈ prs1 ∨ pi ∈ prsR)) ∧
    promise_list_overlap_stronger prsM prs1 ∧
    promise_list_overlap_stronger prsM prsR ∧
    (* [prsM] has enough promises, everything required by [restrict] is there. *)
    promise_list_restrict_stronger prsM prs1 restrict ∧
    promise_list_restrict_stronger prsM prsR restrict.

  Lemma promises_is_valid_restricted_merge_sym prsM prsL prsR restrict :
    promises_is_valid_restricted_merge prsM prsL prsR restrict ↔
      promises_is_valid_restricted_merge prsM prsR prsL restrict.
  Proof.
    unfold promises_is_valid_restricted_merge.
    naive_solver.
  Qed.

  Lemma promise_list_valid_restricted_merge_cons pi prsM prsL prsR restrict :
    pi ∈ prsL ∨ pi ∈ prsR →
    (∀ pia1,
      promises_lookup_at prsL pi.(pi_id) pi.(pi_γ) = Some pia1 →
      promise_stronger pi pia1) →
    (∀ pia2,
      promises_lookup_at prsR pi.(pi_id) pi.(pi_γ) = Some pia2 →
      promise_stronger pi pia2) →
    promises_is_valid_restricted_merge prsM prsL prsR restrict →
    promises_is_valid_restricted_merge (pi :: prsM) prsL prsR restrict.
  Proof.
    intros elm strL strR (elm2 & lsL & lsR & rsL & rsR). split_and!.
    - intros ?. inversion 1; naive_solver.
    - intros ???? look.
      apply promises_lookup_at_cons_Some_inv in look as [(eqId & eqγ & eq)|(? & look)].
      * destruct eqId, eqγ. rewrite -eq. apply strL.
      * apply lsL. done.
    - intros ???? look.
      apply promises_lookup_at_cons_Some_inv in look as [(eqId & eqγ & eq)|(? & look)].
      * destruct eqId, eqγ. rewrite -eq. apply strR.
      * apply lsR. done.
    - intros ???? look.
      destruct (path_equal_or_different id pi.(pi_id) γ pi.(pi_γ))
        as [(-> & ->) | neq].
      * exists pi.
        split; last apply strL; last done.
        apply promises_lookup_at_cons_pr.
      * apply rsL in look as (pia1 & ?); last done.
        exists pia1.
        destruct pi.
        simpl in neq.
        rewrite promises_lookup_at_cons_neq; last naive_solver.
        done.
    - intros ???? look.
      destruct (path_equal_or_different id pi.(pi_id) γ pi.(pi_γ))
        as [(-> & ->) | neq].
      * exists pi.
        split; last apply strR; last done.
        apply promises_lookup_at_cons_pr.
      * apply rsR in look as (pia1 & ?); last done.
        exists pia1.
        destruct pi.
        simpl in neq.
        rewrite promises_lookup_at_cons_neq; last naive_solver.
        done.
  Qed.

  Lemma promise_stronger_pred_stronger id (pia1 pia2 : promise_info_at Ω id) :
    promise_stronger pia1 pia2 → pred_stronger pia1.(pi_pred) pia2.(pi_pred).
  Proof. unfold promise_stronger. naive_solver. Qed.

  Lemma promises_is_valid_restricted_merge_stronger
      owf prsM prsR prsL restrict id γ pia1 pia2 :
    ((MkPi id γ pia1) ∈ prsL ∨ (MkPi id γ pia1) ∈ prsR) →
    promises_wf owf prsL →
    promises_wf owf prsR →
    promises_lookup_at prsM id γ = Some pia2 →
    promises_is_valid_restricted_merge prsM prsL prsR restrict →
    promise_stronger pia2 (MkPi id γ pia1).
  Proof.
    intros [elm|elm] ? ? look (? & str1 & str2 & ? & ?).
    - eapply str1; first done. eapply promises_elem_of; done.
    - eapply str2; first done. eapply promises_elem_of; done.
  Qed.

  (* Get the strongest promise from [prsL] and [prsR]. *)
  Lemma overlap_lookup_left owf prsL prsR id γ pia :
    promises_lookup_at prsL id γ = Some pia →
    promises_overlap_pred prsL prsR →
    promises_wf owf prsL →
    promises_wf owf prsR →
    ∃ pia',
      ((MkPi id γ pia') ∈ prsL ∨ (MkPi id γ pia') ∈ prsR) ∧
      promise_stronger pia' pia ∧
      (∀ pia2,
        promises_lookup_at prsR id γ = Some pia2 →
        promise_stronger pia' pia2).
  Proof.
    intros look1 lap wf1 wf2.
    destruct (promises_lookup_at prsR id γ) as [pia2|] eqn:look2.
    - edestruct lap as [?|?]; [apply look1 | apply look2 | | ].
      + exists pia.
        split_and!.
        * left. apply promises_lookup_at_Some. done.
        * apply promise_stronger_refl.
        * intros pia' [= ->]. done.
      + exists pia2.
        split_and!.
        * right. apply promises_lookup_at_Some. done.
        * done.
        * intros ? [= ->]. apply promise_stronger_refl.
    - exists pia.
      split_and!.
      + left. apply promises_lookup_at_Some. done.
      + apply promise_stronger_refl.
      + naive_solver.
  Qed.

  Lemma promises_well_formed_in_either owf prsL prsR pi wf :
    owf pi.(pi_id) = wf →
    promises_wf owf prsL →
    promises_wf owf prsR →
    (pi ∈ prsL ∨ pi ∈ prsR) →
    ∀ (idx : fin (On Ω pi.(pi_id))),
      ∃ piSat,
        (piSat ∈ prsL ∨ piSat ∈ prsR) ∧
        (* promise_satisfy_dep pi piSat idx wf. *)
        promise_satisfy_dep pi piSat idx wf.
  Proof.
    intros eq wf1 wf2 [[idx look]%elem_of_list_lookup_1 |
                    [idx look]%elem_of_list_lookup_1].
    - intros i.
      eapply promises_well_formed_lookup in wf1; last done.
      destruct (wf1 i) as (piSat & rest).
      exists piSat. naive_solver.
    - intros i.
      eapply promises_well_formed_lookup in wf2; last done.
      destruct (wf2 i) as (piSat & rest).
      exists piSat. naive_solver.
  Qed.

  (* This test serves to demonstrate how destructuring [gc_map Ω id] with some
   * thing of the form [owf id] present in the proof fails. The [generalize
   * dependent] here is necessary for the [destruct] to succeed. A similar
   * destruct is used in the prof of [merge_promises_insert_promise_idx]. *)
  Lemma test_destruct_omega_wf_at (owf : omega_wf (gc_map Ω)) pi piSat idx :
    promise_satisfy_dep pi piSat idx (owf pi.(pi_id)).
  Proof.
    destruct pi. simpl in *.
    unfold promise_satisfy_dep.
    destruct pi_at0. simpl in *.
    unfold Ocs in *.
    unfold lookup_fmap_Ocs in *.
    unfold Ocs_Oids_distr in *.
    unfold lookup_fmap_Ocs in *.
    unfold Ocs_Oids_distr in *.
    unfold Ocs in *.
    unfold Oids in *.
    (* without this generalization the destruct below fails *)
    generalize dependent (owf pi_id0). intros wf.
    unfold omega_wf_at in *.
    destruct (gc_map Ω pi_id0).
  Abort.

  (* Grow [prs3] by inserting the promise id+γ and all of its dependencies from
   * [prsL] and [prsR]. *)
  Lemma merge_promises_insert_promise_idx owf prsL prsR prs3 i pi restrict :
    promises_is_valid_restricted_merge prs3 prsL prsR restrict →
    prsL !! (length prsL - S i) = Some pi →
    promises_overlap_pred prsL prsR →
    promises_wf owf prsL →
    promises_wf owf prsR →
    promises_wf owf prs3 →
    ∃ prs3' pia3,
      promises_lookup_at prs3' (pi.(pi_id)) pi.(pi_γ) = Some pia3 ∧
      promises_wf owf prs3' ∧
      (∀ pi, pi ∈ prs3 → pi ∈ prs3') ∧
      promises_is_valid_restricted_merge prs3' prsL prsR restrict.
  Proof.
    generalize dependent pi.
    generalize dependent prs3.
    induction i as [i IH] using lt_wf_ind.
    intros prs3 [id γ pia] vm look lap wf1 wf2 wf3.
    (* We consider wether the promise is already in the list *)
    destruct (promises_lookup_at prs3 id γ) eqn:notIn.
    { (* The promise is already in the list so inserting it is easy peasy -
       * even a naive solver could do it. *)
      naive_solver. }

    (* We find the promise that we have to insert - the strongest we can find. *)
    edestruct overlap_lookup_left as (piaIns & inEither & stronger & ?).
    { eapply promise_lookup_lookup; last apply look. done. }
    { done. } { done. } { done. }

    (* To add the promise we must first add all of its dependencies. We state
     * that we can do this as a sub-assertion as we need to do a second
     * induction to prove it. *)
    assert (∃ prs3',
      promises_wf owf prs3' ∧
      (∀ pi, pi ∈ prs3 → pi ∈ prs3') ∧
      promises_has_deps (MkPi id γ piaIns) prs3' (owf id) ∧
      promises_is_valid_restricted_merge prs3' prsL prsR restrict)
        as res.
    { simpl.
      specialize (
        promises_well_formed_in_either owf prsL prsR (MkPi id γ piaIns) (owf id) eq_refl wf1 wf2 inEither
      ) as satisfyingPromiseInEither.
      generalize dependent (owf id). intros wf satisfyingPromiseInEither.
      (* We specialize this lemmas such that the following destructs also
       * breaks down this statemens. *)
      specialize (promises_well_formed_lookup_index owf prsL (MkPi id γ pia) i wf1 look) as lem.
      destruct piaIns. simpl in *.
      unfold promise_satisfy_dep in *.
      destruct pia. simpl in *.
      clear look. (* look prevents the destruct below *)
      unfold Ocs in *.
      unfold lookup_fmap_Ocs in *.
      unfold Ocs_Oids_distr in *.
      unfold lookup_fmap_Ocs in *.
      unfold Ocs_Oids_distr in *.
      unfold Ocs in *.
      unfold Oids in *.
      unfold omega_wf_at in *.
      simpl in *.
      destruct stronger as [depsEq impl]. simpl in depsEq. destruct depsEq.
      rewrite /promises_has_deps.
      rewrite /promise_satisfy_dep.
      unfold lookup_fmap_Ocs in *.
      unfold Ocs_Oids_distr in *.
      unfold Ocs in *.
      unfold Oids in *.
      simpl in *.
      clear inEither H.
      simpl in *.
      (* destruct wfEq. *)
      (* clear wfEq. *)
      (* After all the unfolding we can finally carry out this destruct. *)
      destruct (gc_map Ω id).
      simpl in *.
      clear -prs3 notIn vm wf1 wf2 wf3 IH lap lem satisfyingPromiseInEither.
      induction (gcd_n0).
      { (* There are no dependencies. *)
        exists prs3.
        split_and!; try done.
        intros idx. inversion idx. }
      (* There is some number of dependencies an all the lists related to the
       * dependencies must be of the [cons] form. *)
      dependent elimination gcd_deps0 as [icons d_c deps'].
      dependent elimination gcd_deps_ids0 as [icons d_id deps_ids'].
      dependent elimination pi_deps_γs0 as [icons d_γ deps_γs'].
      dependent elimination pi_deps_preds0 as [hcons piaIns_pred deps_preds'].
      dependent elimination pi_deps_preds1 as [hcons pia_pred prec_deps_preds'].
      (* piaIns_pred should be stronger than pia_pred *)
      (* Insert all but the first dependency using the inner induction hypothesis. *)
      specialize (IHn deps' deps_ids' prec_deps_preds' deps_γs' deps_preds' (λ idx, wf (FS idx))) as (prs3' & ? & sub & hasDeps & vm2).
      { intros idx.
        specialize (satisfyingPromiseInEither (FS idx)) as (piSat & ?).
        exists piSat. done. }
        (* exists piSat, (λ i, wf (FS i)). *)
        (* done. } *)
      { intros idx.
        specialize (lem (FS idx)) as (j & pi2 & wf0 & ? & ? & ? & (? & rest)).
        exists j, pi2, (λ i, wf0 (FS i)).
        rewrite hvec_lookup_fmap_equation_3 in rest.
        split_and!; naive_solver. }
      specialize (lem 0%fin) as
        (j & piD & ? & le & look2 & lookDeps & idEq & _).
      (* [piD] is the dependency found in [prsL]. *)
      (* Insert the dependency into [prs3] by using the induction hypothesis. *)
      specialize (IH j le _ piD.(pi_at) vm2 look2 lap wf1 wf2 H)
        as (prs3'' & piaD & ? & ? & sub2 & ?).
      specialize (satisfyingPromiseInEither 0%fin) as (piSat & inEither & ? & (idEq' & stronger')).
      (* [piaD] is the promise that we insert to satisfy the first dependency. *)
      (* What is the relationship between [piaD] and the dependency
       * information stored in [piaIns]? *)
        (* piaIns is from prsL or prsR, one of these have a promise that satisfy *)
      exists prs3''.
      split; first done.
      split. { intros ??. apply sub2. apply sub. done. }
      split; last done.
      (* We need to show that [prs3''] satisfies all the dependency
       * predicates of [piaIns]. *)
      intros idx.
      dependent elimination idx as [FS idx|F0]; last first.
      * specialize (hasDeps idx) as (pSat & elm & deps & (eq & predStronger)).
        exists pSat.
        split. { apply sub2. done. }
        split; first done.
        exists eq.
        rewrite hvec_lookup_fmap_equation_3.
        clear -predStronger.
        apply predStronger.
      * exists (MkPi piD.(pi_id) piD.(pi_γ) piaD).
        split. { apply promises_lookup_at_Some. done. }
        split; first done.
        exists idEq.
        simpl.
        rewrite hvec_lookup_fmap_equation_2.
        rewrite hvec_lookup_fmap_equation_2 in stronger'.
        destruct piD, piSat. simpl in *. subst.
        assert (pred_stronger (pi_pred piaD) (pi_pred pi_at1)).
        { apply promise_stronger_pred_stronger.
          eapply (promises_is_valid_restricted_merge_stronger); done. }
        eapply pred_stronger_trans; first apply H3.
        simpl in *.
        (* specialize (wf 0%fin). *)
        (* destruct (wf 0%fin) as (bingo & bongo & bango). *)
        (* destruct (wfAt4 0%fin) as (bingo2 & bongo2 & bango2). *)
        clear -stronger'.
        apply stronger'. }
    (* end of assert *)
    simpl in res.
    destruct res as (prs3' & ? & sub2 & ? & ?).
    (* Check if the promise we want to insert is now in [prs3']. In reality
     * this will never happend as [prs3'] is only extended with the
     * dependencies of [pi], but it is easier just to consider the case that it
     * might than to carry through the fact that it is not. *)
    destruct (promises_lookup_at prs3' (id) γ) eqn:notIn2.
    { (* The promise is already in the list so inserting it is easy peasy -
       * even a naive solver could do it. *)
      naive_solver. }
    eexists (cons (MkPi id γ piaIns) prs3'), piaIns.
    split_and!.
    + apply promises_lookup_at_cons.
    + split; last done.
      split.
      { intros pi2 in2.
        subst. eapply promises_lookup_at_None; done. }
      { done. }
    + intros ??. apply elem_of_list_further. apply sub2. done.
    + apply promise_list_valid_restricted_merge_cons; try done.
      intros pia2 look2. simpl in look2.
      apply (promise_lookup_lookup owf) in look; last done.
      simpl in look.
      simplify_eq.
      apply stronger.
  Qed.

  Lemma lookup_Some_length {A} (l : list A) i v :
    l !! i = Some v → ∃ j, i = length l - S j.
  Proof.
    intros le% lookup_lt_Some.
    apply Nat.le_exists_sub in le as (i' & ? & _).
    exists i'. lia.
  Qed.

  (* Grow [prsM] by inserting the promise id+γ and all of its dependencies from
   * [prsL] and [prsR]. *)
  Lemma merge_promises_insert_promise owf prsL prsR prsM id γ restrict :
    promises_is_valid_restricted_merge prsM prsL prsR restrict →
    promises_lookup_at prsM id γ = None →
    (is_Some (promises_lookup_at prsL id γ) ∨
      is_Some (promises_lookup_at prsR id γ)) →
    promises_overlap_pred prsL prsR →
    promises_wf owf prsL →
    promises_wf owf prsR →
    promises_wf owf prsM →
    ∃ prsM' pia3,
      promises_wf owf prsM' ∧
      promises_lookup_at prsM' id γ = Some pia3 ∧
      promises_is_valid_restricted_merge prsM' prsL prsR restrict.
  Proof.
    intros val _ [[? sm]|[? sm]] lap wf1 wf2 wfM.
    - apply promises_lookup_at_Some_lookup in sm as [i look].
      pose proof look as look2.
      apply lookup_Some_length in look2 as (i' & ->).
      edestruct merge_promises_insert_promise_idx as (prsM' & pia3 & ?); try done.
      exists prsM', pia3.
      naive_solver.
    - apply promises_lookup_at_Some_lookup in sm as [i look].
      apply promises_overlap_pred_sym in lap.
      apply promises_is_valid_restricted_merge_sym in val.
      pose proof look as look2.
      apply lookup_Some_length in look2 as (i' & ->).
      edestruct merge_promises_insert_promise_idx as (prsM' & pia3 & ?);
        try apply look; try done.
      exists prsM', pia3.
      rewrite promises_is_valid_restricted_merge_sym.
      naive_solver.
  Qed.

  Lemma merge_promises_restriced owf prsL prsR (restrict : list (ggid Ω * gname)) :
    promises_overlap_pred prsL prsR →
    promises_wf owf prsL →
    promises_wf owf prsR →
    ∃ prsM,
      promises_wf owf prsM ∧
      promises_is_valid_restricted_merge prsM prsL prsR restrict.
  Proof.
    rewrite /promises_is_valid_restricted_merge.
    intros lap wf1 wf2.
    induction restrict as [|[id γ] restrict' IH].
    { exists []. rewrite /promise_list_restrict_stronger.
      split_and!; try done; setoid_rewrite elem_of_nil; done. }
    destruct IH as (prsM & wf3 & from & lap1 & lap2 & stronger1 & stronger2).
    (* We're good if id+γ is already in [restrict']. *)
    destruct (decide ((id, γ) ∈ restrict')) as [elm|notElm].
    { exists prsM. rewrite /promise_list_restrict_stronger.
      setoid_rewrite (elem_of_elem_of_cons _ _ _ elm).
      done. }
    (* If the promise is already in [prsM] it should satisfy the conditions
     * already for the expanded [restrict]. *)
    destruct (promises_lookup_at prsM id γ) as [pia3|] eqn:look.
    { exists prsM. split_and!; try done.
      - eapply promise_list_restrict_stronger_cons; try done.
      - eapply promise_list_restrict_stronger_cons; done. }
    destruct (promises_lookup_at prsL id γ) as [pia1|] eqn:look1;
      destruct (promises_lookup_at prsR id γ) as [pia2|] eqn:look2.
    - edestruct (merge_promises_insert_promise) as (prs3' & temp);
        try done; first naive_solver.
      destruct temp as (pia3 & look3 & ? & ? & ? & ? & ? & ?).
      exists prs3'.
      split_and!; try done.
       * eapply promise_list_restrict_stronger_cons; done.
       * eapply promise_list_restrict_stronger_cons; done.
    - edestruct (merge_promises_insert_promise) as (prs3' & temp);
        try done; first naive_solver.
      destruct temp as (pia3 & look3 & ? & ? & ? & ? & ? & ?).
      exists prs3'.
      split_and!; try done.
       * eapply promise_list_restrict_stronger_cons; done.
       * eapply promise_list_restrict_stronger_cons; done.
    - edestruct (merge_promises_insert_promise) as (prs3' & temp);
        try done; first naive_solver.
      destruct temp as (pia3 & look3 & ? & ? & ? & ? & ? & ?).
      exists prs3'.
      split_and!; try done.
       * eapply promise_list_restrict_stronger_cons; done.
       * eapply promise_list_restrict_stronger_cons; done.
    - (* None of the promise lists have the promise in question. *)
      exists prsM.
      split_and!; try done.
      * intros ???. inversion 1; subst.
        + congruence.
        + apply stronger1. done.
      * intros ???. inversion 1; subst.
        + congruence.
        + apply stronger2. done.
  Qed.

  Definition promises_is_valid_merge prsM prsL prsR :=
    (∀ pi, pi ∈ prsM → pi ∈ prsL ∨ pi ∈ prsR) ∧
    promise_list_stronger prsM prsL ∧
    promise_list_stronger prsM prsR.

  Definition promise_get_path (pi : promise_info Ω) := (pi.(pi_id), pi.(pi_γ)).

  Definition restrict_merge prsL prsR :=
    (promise_get_path <$> prsL) ++ (promise_get_path <$> prsR).

  Lemma restrict_merge_lookup_Some prsL prsR id γ :
    is_Some (promises_lookup_at prsL id γ) →
    (id, γ) ∈ restrict_merge prsL prsR.
  Proof.
    intros (? & look%promises_lookup_at_Some).
    apply elem_of_app.
    left.
    apply elem_of_list_fmap.
    eexists _. split; last done. done.
  Qed.

  (* How to merge promises, intuitively?
   * 1. From the first list add the suffix of promises not in the other.
   * 2. From the second list add the suffix of promises not in the other.
   * 3. The last element in both lists is now also present in the other.
   *    - If they are for the same id+γ then add the strongest.
   *    - If one of them is stronger than the one in the other list then add that one.
   *    - If they are both weaker???
   *)
  Lemma merge_promises owf prsL prsR :
    promises_overlap_pred prsL prsR →
    promises_wf owf prsL →
    promises_wf owf prsR →
    ∃ prs3,
      promises_wf owf prs3 ∧ promises_is_valid_merge prs3 prsL prsR.
  Proof.
    intros lap wf1 wf2.
    destruct (merge_promises_restriced owf prsL prsR (restrict_merge prsL prsR) lap wf1 wf2)
      as (prs3 & ? & (? & ? & ? & str1 & str2)).
    exists prs3.
    split; first done.
    split_and!.
    - done.
    - intros ??? look. apply str1; last done.
      apply restrict_merge_lookup_Some.
      done.
    - intros ??? look. apply str2; last done.
      assert ((id, γ) ∈ restrict_merge prsR prsL) as elm.
      { apply restrict_merge_lookup_Some; try done. }
      move: elm.
      rewrite !elem_of_app.
      naive_solver.
  Qed.

End promise_info.

Section transmap.
  Context `{Ω : gGenCmras Σ}.

  Implicit Types (transmap : TransMap Ω).
  Implicit Types (ps : list (promise_info Ω)).

  (* We need to:
    - Be able to turn a list of promises and a map of picks into a
      global transformation.
    - Say that a set of picks respects a list of promises.
    - Merge two lists of promises.
   *)

  (** The vector [trans] contains at every index the transition for the
   * corresponding dependency in [p] from [transmap] *)
  Definition trans_at_deps transmap (i : ggid Ω) (γs : ivec (On Ω i) gname)
      (ts : hvec (On Ω i) (cmra_to_trans <$> Ocs Ω i)) :=
    ∀ idx,
      let id := Oids Ω i !!! idx in
      let t : Oc Ω id → Oc Ω id := lookup_fmap_Ocs ts idx (Ω.(gc_map_wf) i) in
      transmap id !! (γs !!! idx) = Some t.

  (** The transformations in [transmap] satisfy the relation in [p]. *)
  Definition transmap_satisfy_rel transmap p :=
    ∃ ts t,
      transmap p.(pi_id) !! p.(pi_γ) = Some t ∧
      trans_at_deps transmap p.(pi_id) p.(pi_deps_γs) ts ∧
      huncurry p.(pi_rel) ts t.

  (** The [transmap] respect the promises in [ps]: There is a pick for every
   * promise and all the relations in the promises are satisfied by the
   * transformations in transmap. *)
  Definition transmap_resp_promises transmap ps :=
    Forall (transmap_satisfy_rel transmap) ps.

  Definition Oc_trans_transport {id1 id2} (eq : id1 = id2)
    (o : Oc Ω id1 → _) : Oc Ω id2 → Oc Ω id2 :=
      eq_rect _ (λ id, Oc Ω id → Oc Ω id) o _ eq.

  Lemma promises_has_deps_resp_promises p idx promises transmap :
    promises_has_deps p promises (Ω.(gc_map_wf) p.(pi_id)) →
    transmap_resp_promises transmap promises →
    ∃ t, (pi_deps_pred p idx (Ω.(gc_map_wf) p.(pi_id))) t ∧
         transmap (pi_deps_id p idx) !! (p.(pi_deps_γs) !!! idx) = Some t.
  Proof.
    intros hasDeps resp.
    rewrite /transmap_resp_promises Forall_forall in resp.
    specialize (hasDeps idx) as (p2 & Helem & eq1 & eq2 & strong).
    destruct (resp _ Helem) as (ts & (t & tmLook & ? & relHolds)).
    specialize (p2.(pi_rel_to_pred) ts t relHolds) as predHolds.
    exists (Oc_trans_transport (eq_sym eq2) t).
    split.
    * apply strong in predHolds.
      clear -predHolds. destruct eq2. simpl. done.
    * rewrite eq1. clear -tmLook. destruct eq2. apply tmLook.
  Qed.

  (* What would a more general version of this lemma look like? *)
  Lemma rew_cmra_to_pred (x : cmra) f y (eq : x = y) t :
    (eq_rect x pred_over f y eq) t = f (eq_rect_r cmra_to_trans t eq).
  Proof. destruct eq. done. Qed.

  (** If a [transmap] respects a list [promises] and growing the list with [p]
   * is well formed, then we can conjur up a list of transitions from
   * [transmap] that match the dependencies in [p] and that satisfy their
   * predicates. *)
  Lemma transmap_satisfy_wf_cons p promises transmap :
    promises_wf (Ω.(gc_map_wf)) (p :: promises) →
    transmap_resp_promises transmap promises →
    ∃ ts,
      trans_at_deps transmap p.(pi_id) p.(pi_deps_γs) ts ∧
      preds_hold p.(pi_deps_preds) ts.
  Proof.
    intros WF resp.
    destruct WF as [[uniq hasDeps] WF'].
    edestruct (fun_ex_to_ex_hvec_fmap (F := cmra_to_trans) (Ocs Ω (pi_id p))
      (λ i t,
        let t' := eq_rect _ _ t _ (Ocs_Oids_distr p.(pi_id) _ (Ω.(gc_map_wf) _)) in
        let pred := hvec_lookup_fmap p.(pi_deps_preds) i in
        pred t ∧
        transmap (Oids Ω p.(pi_id) !!! i) !! (p.(pi_deps_γs) !!! i) = Some t'))
      as (ts & ?).
    { intros idx.
      specialize (promises_has_deps_resp_promises _ idx _ transmap hasDeps resp).
      intros (t & ? & ?).
      exists (eq_rect_r _ t (Ocs_Oids_distr _ _ (Ω.(gc_map_wf) _))).
      simpl.
      split.
      * rewrite /lookup_fmap_Ocs in H.
        simpl in H.
        clear -H.
        rewrite <- rew_cmra_to_pred.
        apply H.
      * rewrite H0.
        rewrite rew_opp_r.
        done. }
    exists ts.
    split.
    - intros di. apply H.
    - apply preds_hold_alt. intros di.
      apply (H di).
  Qed.

  Equations transmap_insert_go transmap (id : ggid Ω) (γ : gname) (pick : Oc Ω id → Oc Ω id)
    (id' : ggid Ω) : gmap gname (Oc Ω id' → Oc Ω id') :=
  | transmap, _, γ, pick, id', with decide (id = id') => {
    | left eq_refl => <[ γ := pick ]>(transmap id')
    | right _ => transmap id'
  }.

  Definition transmap_insert transmap id γ pick : TransMap Ω :=
    transmap_insert_go transmap id γ pick.

  Lemma transmap_insert_lookup transmap id γ t  :
    (transmap_insert transmap id γ t) id !! γ = Some t.
  Proof.
    rewrite /transmap_insert.
    rewrite transmap_insert_go_equation_1.
    destruct (decide (id = id)) as [eq | neq]; last congruence.
    assert (eq = eq_refl) as ->.
    { rewrite (proof_irrel eq eq_refl). done. }
    simpl.
    rewrite lookup_insert. done.
  Qed.

  Lemma transmap_insert_lookup_ne transmap id1 γ1 t id2 γ2 :
    id1 ≠ id2 ∨ γ1 ≠ γ2 →
    (transmap_insert transmap id1 γ1 t) id2 !! γ2 = transmap id2 !! γ2.
  Proof.
    intros neq.
    rewrite /transmap_insert.
    rewrite transmap_insert_go_equation_1.
    destruct (decide (id1 = id2)) as [eq | neq2]; last done.
    destruct neq as [neq | neq]; first congruence.
    subst. simpl.
    rewrite lookup_insert_ne; done.
  Qed.

  Lemma transmap_insert_subseteq_r i γ t transmap1 transmap2 :
    transmap1 i !! γ = None →
    transmap1 ⊆ transmap2 →
    transmap1 ⊆ transmap_insert transmap2 i γ t.
  Proof.
    intros look sub.
    intros i'.
    apply map_subseteq_spec => γ' t' look'.
    destruct (decide (i = i' ∧ γ = γ')) as [[-> ->]|Hneq].
    - congruence.
    - rewrite transmap_insert_lookup_ne.
      * specialize (sub i').
        rewrite map_subseteq_spec in sub.
        apply sub.
        done.
      * apply not_and_r in Hneq; done.
  Qed.

  Lemma transmap_resp_promises_insert owf p promises transmap t :
    promises_wf owf (p :: promises) →
    transmap_resp_promises transmap promises →
    transmap_resp_promises (transmap_insert transmap (pi_id p) (pi_γ p) t) promises.
  Proof.
    intros [[uniq hasDeps] WF].
    rewrite /transmap_resp_promises !Forall_forall.
    intros impl p2 elem.
    destruct (impl _ elem) as (t' & ts & rest).
    exists t', ts.
    rewrite /trans_at_deps.
    (* NOTE: This proof might be a bit of a mess. *)
    setoid_rewrite transmap_insert_lookup_ne.
    + apply rest.
    + apply (uniq _ elem).
    + apply elem_of_list_lookup_1 in elem as (? & look).
      specialize (
        promises_well_formed_lookup owf promises _ p2 WF look) as hasDeps2.
      specialize (hasDeps2 idx) as (p3 & look3 & eq & eq2 & ?).
      simpl in *.
      rewrite eq2.
      destruct p3.
      rewrite eq.
      specialize (uniq _ look3) as [? | ?].
      - left. done.
      - right. done.
  Qed.

  Lemma transmap_resp_promises_weak owf transmap prsL prsR :
    promises_wf owf prsR →
    promise_list_stronger prsL prsR →
    transmap_resp_promises transmap prsL →
    transmap_resp_promises transmap prsR.
  Proof.
    intros wf strong.
    rewrite /transmap_resp_promises.
    rewrite !Forall_forall.
    intros resp [id γ pia2] elm.
    destruct (strong id γ pia2) as (pia1 & look2 & stronger).
    { apply (promises_elem_of owf); done. }
    destruct (resp (MkPi id γ pia1)) as (? & ? & ? & ? & ?).
    { apply promises_lookup_at_Some. done. }
    eexists _, _.
    split; first done.
    split.
    { rewrite /trans_at_deps. simpl.
      destruct stronger as [<- ho].
      apply H0. }
    simpl.
    apply stronger.
    done.
  Qed.

  Lemma transmap_resp_promises_lookup_at transmap promises id γ pia :
    transmap_resp_promises transmap promises →
    promises_lookup_at promises id γ = Some pia →
    transmap_satisfy_rel transmap (MkPi id γ pia).
  Proof.
    rewrite /transmap_resp_promises Forall_forall.
    intros resp ?%promises_lookup_at_Some.
    apply resp. done.
  Qed.

  Definition transmap_overlap_resp_promises transmap ps :=
    ∀ i p, ps !! i = Some p →
      transmap_satisfy_rel transmap p ∨ (transmap p.(pi_id) !! p.(pi_γ) = None).

  Lemma trans_at_deps_subseteq transmap1 transmap2 id γs ts :
    transmap1 ⊆ transmap2 →
    trans_at_deps transmap1 id γs ts →
    trans_at_deps transmap2 id γs ts.
  Proof.
    intros sub ta.
    intros idx. simpl.
    specialize (sub (Oids Ω id !!! idx)).
    rewrite map_subseteq_spec in sub.
    specialize (ta idx).
    apply sub.
    apply ta.
  Qed.

  Lemma trans_at_deps_union_l picks1 picks2 i t1 c1 :
    trans_at_deps picks1 i t1 c1 →
    trans_at_deps (picks1 ∪ picks2) i t1 c1.
  Proof.
    apply trans_at_deps_subseteq.
    apply transmap_union_subseteq_l.
  Qed.

  Lemma trans_at_deps_union_r picks1 picks2 i t2 c2 :
    (∀ i, map_agree_overlap (picks1 i) (picks2 i)) →
    trans_at_deps picks2 i t2 c2 →
    trans_at_deps (picks1 ∪ picks2) i t2 c2.
  Proof.
    intros over.
    apply trans_at_deps_subseteq.
    apply transmap_union_subseteq_r.
    done.
  Qed.

  Lemma transmap_overlap_resp_promises_cons transmap p promises :
    transmap_overlap_resp_promises transmap (p :: promises) →
    transmap_overlap_resp_promises transmap promises.
  Proof. intros HL. intros i ? look. apply (HL (S i) _ look). Qed.

  (* Grow a transformation map to satisfy a list of promises. This works by
  * traversing the promises and using [promise_info] to extract a
  * transformation. *)
  Lemma transmap_promises_to_maps transmap promises :
    transmap_overlap_resp_promises transmap promises →
    promises_wf (Ω.(gc_map_wf)) promises →
    ∃ (map : TransMap Ω),
      transmap_resp_promises map promises ∧
      transmap ⊆ map.
  Proof.
    induction promises as [|p promises' IH].
    - intros _. exists transmap.
      split; last done.
      apply Forall_nil_2.
    - intros HR [WF WF'].
      specialize (promise_wf_neq_deps _ _ _ WF) as depsDiff.
      destruct IH as (map & resp & sub).
      {  eapply transmap_overlap_resp_promises_cons. done. } { done. }
      (* We either need to use the transformation in [picks] or extract one
       * from [p]. *)
      destruct (transmap p.(pi_id) !! p.(pi_γ)) eqn:look.
      + destruct (HR 0 p) as [sat | ?]; [done | | congruence].
        destruct sat as (ts & t & transIn & hold & pRelHolds).
        exists map. (* We don't insert as map already has transformation. *)
        split; last done.
        apply Forall_cons.
        split; try done.
        eexists _, _. split_and!; last done.
        -- specialize (sub p.(pi_id)).
           rewrite map_subseteq_spec in sub.
           apply sub.
           done.
        -- eapply trans_at_deps_subseteq; done.
      + eassert _ as sat.
        { eapply transmap_satisfy_wf_cons; done. }
        destruct sat as (ts & transIn & hold).
        eassert (∃ t, _) as [t pRelHolds].
        { apply p.(pi_witness). apply hold. }
        exists (transmap_insert map p.(pi_id) p.(pi_γ) t).
        split.
        * apply Forall_cons.
          split.
          -- rewrite /transmap_satisfy_rel.
            exists ts, t.
            split. { by rewrite transmap_insert_lookup. }
            split; last done.
            intros ??.
            simpl.
            rewrite transmap_insert_lookup_ne; first apply transIn.
            apply depsDiff.
          -- apply (transmap_resp_promises_insert Ω.(gc_map_wf)); done.
        * apply transmap_insert_subseteq_r; done.
  Qed.

  Lemma promises_to_maps (promises : list _) :
    promises_wf Ω.(gc_map_wf) promises →
    ∃ (transmap : TransMap _), transmap_resp_promises transmap promises.
  Proof.
    intros WF.
    edestruct (transmap_promises_to_maps (λ i : ggid Ω, ∅)) as [m [resp a]].
    2: { done. }
    - intros ???. right. done.
    - exists m. apply resp.
  Qed.

End transmap.

(* Arguments promise_info Σ : clear implicits. *)
(* Arguments promise_self_info Σ : clear implicits. *)

Definition Oown {Σ} {Ω : gGenCmras Σ} (i : ggid Ω) γ a :=
  @own _ _ (gen_cmra_data_to_inG (Ω.(gc_map) i)) γ a.

Section rules.
  Context {n : nat} {DS : ivec n cmra} `{i : !genInG Σ Ω A DS}.

  Lemma own_gen_cmra_data_to_inG γ (a : generational_cmraR A DS) :
    own γ a = Oown (genInG_id i) γ (rew omega_genInG_cmra_eq in a).
  Proof.
    (* Note, the way a [genInG] creates an [inG] instance is carefully defined
     * to match [Oown] to make this lemma be provable only with
     * [eq_trans_rew_distr]. *)
    rewrite /Oown own.own_eq /own.own_def /own.iRes_singleton.
    unfold cmra_transport.
    rewrite eq_trans_rew_distr.
    done.
  Qed.

  Lemma own_gen_cmra_data_to_inG' γ (a : generational_cmraR _ _) :
    own γ (rew <- omega_genInG_cmra_eq in a) = Oown (genInG_id i) γ a.
  Proof. rewrite own_gen_cmra_data_to_inG. rewrite rew_opp_r. done. Qed.

End rules.

Lemma own_eq `{inG Σ A} γ (a b : A) : a = b → own γ a -∗ own γ b.
Proof. intros ->. done. Qed.

Section next_gen_definition.
  Context `{Ω : gGenCmras Σ}.

  Implicit Types (picks : TransMap Ω).

  (* Every generational ghost location consists of a camera and a list of
   * cameras for the dependencies. *)

  (* If a transformation has been picked for one ghost name, then all the
   * dependencies must also have been picked. *)

  (* The resource contains the agreement resources for all the picks in
   * [picks]. We need to know that a picked transformation satisfies the most
   * recent/strongest promise. We thus need the authorative part of the
   * promises. *)
  Definition own_picks picks : iProp Σ :=
    ∀ (i : ggid Ω) γ t,
      ⌜ picks i !! γ = Some t ⌝ -∗
      ∃ (ts : hvec (On Ω i) (cmra_to_trans <$> Ocs Ω i))
          (γs : ivec (On Ω i) gname) Ps R Rs,
        let ing := gen_cmra_data_to_inG (Ω.(gc_map) i) in
        ⌜ trans_at_deps picks i γs ts ⌝ ∧
        ⌜ huncurry R ts t ⌝ ∧
        ⌜ rel_prefix_list_for rel_weaker Rs R ⌝ ∧
        own γ (
          (ε, GTS_tok_gen_shot t, ε, Some (to_agree (ivec_to_list γs)),
           gV (●ML□ Rs), gV (●ML□ Ps)
        ) : generational_cmraR _ _).

  (* This could be generalized to abritrary camera morphisms and upstreamed *)
  Instance cmra_transport_coreid i (a : R Σ i) :
    CoreId a → CoreId (map_unfold (Σ := Σ) a).
  Proof.
    intros ?. rewrite /map_unfold.
    rewrite /CoreId.
    rewrite -cmra_morphism_pcore.
    rewrite core_id.
    done.
  Qed.

  Definition own_promise_info_resource (pi : promise_info Ω)
    (Rs : list (rel_over (Ocs Ω pi.(pi_id)) _))
    (Ps : list (pred_over (Oc Ω pi.(pi_id)))) : iProp Σ :=
    Oown pi.(pi_id) pi.(pi_γ) ((
      ε, ε, ε, Some (to_agree (ivec_to_list pi.(pi_deps_γs))),
      gPV (◯ML Rs), gPV (◯ML Ps)
    ) : generational_cmraR _ _).

  Definition own_promise_info (pi : promise_info Ω) : iProp Σ :=
    ∃ Rs (Ps : list (pred_over (Oc Ω pi.(pi_id)))),
      ⌜ pred_prefix_list_for' Rs Ps pi.(pi_rel) pi.(pi_pred) ⌝ ∗
      own_promise_info_resource pi Rs Ps.

  #[global]
  Instance own_promise_info_persistent pi : Persistent (own_promise_info pi).
  Proof. apply _. Qed.

  Definition own_promises (ps : list (promise_info Ω)) : iProp Σ :=
    [∗ list] p ∈ ps, own_promise_info p.

  #[global]
  Instance own_promises_persistent ps : Persistent (own_promises ps).
  Proof. apply _. Qed.

  Definition nextgen P : iProp Σ :=
    ∃ picks (ps : list (promise_info Ω)),
      (* We own resources for everything in [picks] and [promises]. *)
      own_picks picks ∗ own_promises ps ∗
      ⌜ promises_wf Ω.(gc_map_wf) ps ⌝ ∗
      ∀ full_picks (val : transmap_valid full_picks),
        ⌜ transmap_resp_promises full_picks ps ⌝ -∗
        ⌜ picks ⊆ full_picks ⌝ -∗
        let _ := build_trans_generation full_picks val in
        ⚡={build_trans full_picks}=> P.

End next_gen_definition.

Notation "⚡==> P" := (nextgen P)
  (at level 99, P at level 200, format "⚡==>  P") : bi_scope.

Section own_picks_properties.
  Context `{Ω : gGenCmras Σ}.
  Implicit Types (picks : TransMap Ω).

  Lemma tokens_for_picks_agree_overlap picks1 picks2 :
    own_picks picks1 -∗
    own_picks picks2 -∗
    ⌜ ∀ i, map_agree_overlap (picks1 i) (picks2 i) ⌝.
  Proof.
    iIntros "m1 m2". iIntros (i).
    iIntros (γ a1 a2 look1 look2).
    iDestruct ("m1" $! i γ _ look1) as (????????) "O1".
    iDestruct ("m2" $! i γ _ look2) as (????????) "O2".
    simplify_eq.
    iDestruct (own_valid_2 with "O1 O2") as "#Hv".
    rewrite prod_valid_2nd.
    rewrite GTS_tok_gen_shot_agree.
    iApply "Hv".
  Qed.

  Lemma cmra_transport_validI {A B : cmra} (eq : A =@{cmra} B) (a : A) :
    ✓ cmra_transport eq a ⊣⊢@{iPropI Σ} ✓ a.
  Proof. destruct eq. done. Qed.

  Lemma own_picks_sep picks1 picks2 :
    own_picks picks1 -∗
    own_picks picks2 -∗
    own_picks (picks1 ∪ picks2) ∗ ⌜ picks2 ⊆ picks1 ∪ picks2 ⌝.
  Proof.
    iIntros "O1 O2".
    (* iDestruct 1 as (m1) "[O1 %R1]". *)
    (* iDestruct 1 as (m2) "[O2 %R2]". *)
    iDestruct (tokens_for_picks_agree_overlap with "O1 O2") as %disj.
      (* [done|done|]. *)
    iSplit; last first. { iPureIntro. apply transmap_union_subseteq_r. done. }
    iIntros (i γ t [look|[? look]]%lookup_union_Some_raw).
    - iDestruct ("O1" $! i γ t look) as (????????) "O".
      repeat iExists _.
      iSplit. { iPureIntro. apply trans_at_deps_union_l; done. }
      iSplit; first done.
      iSplit; first done.
      iFrame.
    - iDestruct ("O2" $! i γ t look) as (????????) "O".
      repeat iExists _.
      iSplit. { iPureIntro. apply trans_at_deps_union_r; done. }
      iSplit; first done.
      iSplit; first done.
      iFrame.
  Qed.

End own_picks_properties.

Section own_promises_properties.
  Context `{Ω : gGenCmras Σ}.

  Implicit Types (prs : list (promise_info Ω)).

  Lemma prefix_of_eq_length {A} (l1 l2 : list A) :
    length l2 ≤ length l1 → l1 `prefix_of` l2 → l2 = l1.
  Proof.
    intros len [[|a l] eq].
    - rewrite -app_nil_end in eq. done.
    - assert (length l2 = length (l1 ++ a :: l)) by (rewrite eq; done).
      rewrite app_length /= in H. lia.
  Qed.

  Lemma prefix_of_disj {A} (l1 l2 : list A) :
    length l1 ≤ length l2 →
    l1 `prefix_of` l2 ∨ l2 `prefix_of` l1 →
    l1 `prefix_of` l2.
  Proof.
    intros len [pref|pref]; first done.
    assert (l1 = l2) as ->; last done.
    apply prefix_of_eq_length; done.
  Qed.

  Lemma prefix_of_conj_disj {A B} (ls1 ls2 : list A) (ls3 ls4 : list B):
    length ls1 = length ls3 →
    length ls2 = length ls4 →
    (ls1 `prefix_of` ls2 ∨ ls2 `prefix_of` ls1) →
    (ls3 `prefix_of` ls4 ∨ ls4 `prefix_of` ls3) →
    (ls1 `prefix_of` ls2 ∧ ls3 `prefix_of` ls4) ∨
    (ls2 `prefix_of` ls1 ∧ ls4 `prefix_of` ls3).
  Proof.
    intros len1 len2 [pre1|pre1] disj.
    - left. split; first done.
      apply prefix_of_disj; last done.
      apply prefix_length in pre1.
      lia.
    - right. split; first done.
      apply prefix_of_disj; last naive_solver.
      apply prefix_length in pre1.
      lia.
  Qed.

  Lemma pred_prefix_list_for_stronger id Rs Rs0 Ps Ps0
      (p1 p2 : promise_info_at Ω id) :
    pred_prefix_list_for' Rs Ps (pi_rel p1) (pi_pred p1) →
    pred_prefix_list_for' Rs0 Ps0 (pi_rel p2) (pi_pred p2) →
    pi_deps_γs p1 = pi_deps_γs p2 →
    Rs `prefix_of` Rs0 ∨ Rs0 `prefix_of` Rs →
    Ps `prefix_of` Ps0 ∨ Ps0 `prefix_of` Ps →
    promise_stronger p1 p2 ∨ promise_stronger p2 p1.
  Proof.
    intros (len1 & relPref1 & predPref1 & impl1).
    intros (len2 & relPref2 & predPref2 & impl2).
    intros depsEq rPref pPred.
    destruct (prefix_of_conj_disj Rs Rs0 Ps Ps0) as [[pref1 pref2]|[??]]; try done.
    - rewrite /promise_stronger.
      right.
      split; first done.
      split.
      * apply rel_weaker_stronger.
        apply: pred_prefix_list_for_prefix_of; done.
      * apply pred_weaker_stronger.
        apply: pred_prefix_list_for_prefix_of; try done.
    - left.
      split; first done.
      split.
      * apply rel_weaker_stronger.
        apply: pred_prefix_list_for_prefix_of; done.
      * apply pred_weaker_stronger.
        apply: pred_prefix_list_for_prefix_of; try done.
  Qed.

  (* If two promise lists has an overlap then one of the overlapping promises
   * is strictly stronger than the other. *)
  Lemma own_promises_overlap prsL prsR :
    own_promises prsL -∗
    own_promises prsR -∗
    ⌜ promises_overlap_pred prsL prsR ⌝.
  Proof.
    iIntros "O1 O2".
    iIntros (id γ p1 p2 look1 look2).
    apply promises_lookup_at_Some in look1 as elem1.
    apply promises_lookup_at_Some in look2 as elem2.
    unfold own_promises.
    rewrite big_sepL_elem_of; last done.
    rewrite big_sepL_elem_of; last done.
    iDestruct "O1" as (???) "O1".
    iDestruct "O2" as (???) "O2".
    simpl in *.
    iDestruct (own_valid_2 with "O1 O2") as "#Hv".
    rewrite -5!pair_op.
    iDestruct (prod_valid_4th with "Hv") as %Hv2.
    iDestruct (prod_valid_5th with "Hv") as %Hv.
    iDestruct (prod_valid_6th with "Hv") as %Hv3.
    iPureIntro.
    rewrite -Some_op Some_valid to_agree_op_valid_L in Hv2.
    apply ivec_to_list_inj in Hv2.
    rewrite gen_pv_op gen_pv_valid auth_frag_op_valid in Hv.
    rewrite gen_pv_op gen_pv_valid auth_frag_op_valid in Hv3.
    apply to_max_prefix_list_op_valid_L in Hv.
    apply to_max_prefix_list_op_valid_L in Hv3.
    eapply pred_prefix_list_for_stronger; done.
  Qed.

End own_promises_properties.

(* In this section we prove structural rules of the nextgen modality. *)

Section nextgen_properties.
  Context {Σ : gFunctors} {Ω : gGenCmras Σ}.
  Implicit Types (P : iProp Σ) (Q : iProp Σ).

  (* Lemma res_for_picks_empty : *)
  (*   res_for_picks (λ i : gid Σ, ∅) ε. *)
  (* Proof. done. Qed. *)

  Lemma own_picks_empty :
    ⊢@{iProp Σ} own_picks (λ i, ∅).
  Proof. iIntros (????). done. Qed.

  Lemma own_promises_empty :
    ⊢@{iProp Σ} own_promises [].
  Proof. iApply big_sepL_nil. done. Qed.

  Lemma nextgen_emp_2 : emp ⊢@{iProp Σ} ⚡==> emp.
  Proof.
    iIntros "E".
    rewrite /nextgen.
    iExists (λ i, ∅), [].
    iSplitL "". { iApply own_picks_empty. }
    iSplitL "". { iApply own_promises_empty. }
    iSplit; first done.
    iIntros (full_picks ?) "? ?".
    iModIntro.
    iFrame "E".
  Qed.

  Lemma big_sepL_forall_elem_of {A} (l : list A) Φ :
    (∀ x, Persistent (Φ x)) →
    ([∗ list] x ∈ l, Φ x) ⊣⊢@{iProp Σ} (∀ x, ⌜x ∈ l⌝ → Φ x).
  Proof.
    intros ?. rewrite big_sepL_forall. iSplit.
    - iIntros "H" (? [? elem]%elem_of_list_lookup_1). iApply "H". done.
    - iIntros "H" (?? ?%elem_of_list_lookup_2). iApply "H". done.
  Qed.

  Lemma own_promises_merge prsL prsR :
    promises_wf Ω.(gc_map_wf) prsL →
    promises_wf Ω.(gc_map_wf) prsR →
    own_promises prsL -∗
    own_promises prsR -∗
    ∃ prsM,
      ⌜ promises_wf Ω.(gc_map_wf) prsM ⌝ ∗
      ⌜ promises_is_valid_merge prsM prsL prsR ⌝ ∗
      own_promises prsM.
  Proof.
    iIntros (wfL wfR) "prL prR".
    iDestruct (own_promises_overlap with "prL prR") as %lap.
    destruct (merge_promises Ω.(gc_map_wf) prsL prsR) as (prsM & ? & ? & ? & ?);
      [done|done|done|].
    iExists prsM.
    iSplit; first done.
    iSplit; first done.
    unfold own_promises.
    rewrite 3!big_sepL_forall_elem_of.
    iIntros (pi elm).
    edestruct (H0) as [elm2|elm2]; first apply elm.
    - iDestruct ("prL" $! _ elm2) as (??) "?".
      iExists _, _. iFrame.
    - iDestruct ("prR" $! _ elm2) as (??) "?".
      iExists _, _. iFrame.
  Qed.

  Lemma nextgen_sep_2 P Q :
    (⚡==> P) ∗ (⚡==> Q) ⊢ ⚡==> (P ∗ Q) .
  Proof.
    rewrite /nextgen.
    iIntros "[P Q]".
    iDestruct "P" as (? prs1) "(picks1 & pr1 & %wf1 & HP)".
    iDestruct "Q" as (? prs2) "(picks2 & pr2 & %wf2 & HQ)".
    iDestruct (own_promises_merge prs1 prs2 with "pr1 pr2") as "(%prs3 & %wf3 & (% & % & %) & prs3)";
      [done|done| ].
    iExists _, prs3.
    iDestruct (own_picks_sep with "picks1 picks2") as "[$ %sub]".
    iFrame "prs3".
    iSplit; first done.
    iIntros (fp vv a b).
    iSpecialize ("HP" $! fp vv with "[%] [%]").
    { eapply transmap_resp_promises_weak; done. }
    { etrans; last done. apply transmap_union_subseteq_l. }
    iSpecialize ("HQ" $! fp vv with "[%] [%]").
    { eapply transmap_resp_promises_weak; done. }
    { etrans; done. }
    iModIntro.
    iFrame.
  Qed.

End nextgen_properties.

(* Ownership over generational ghost state. *)

Section generational_resources.
  Context {n} {A} {DS : ivec n cmra} `{i : !genInG Σ Ω A DS}.
  Implicit Types (R : rel_over DS A) (P : (A → A) → Prop).

  Definition gen_picked_in γ (t : A → A) : iProp Σ :=
    own γ (gc_tup_pick_in DS t).

  Definition gen_pick_out γ r : iProp Σ :=
    own γ (gc_tup_pick_out DS r).

  (* The generational version of [own] that should be used instead of [own]. *)
  Definition gen_own (γ : gname) (a : A) : iProp Σ :=
    own γ (gc_tup_elem DS a).

  Definition know_deps γ (γs : ivec n gname) : iProp Σ :=
    own γ (gc_tup_deps A DS (ivec_to_list γs)).

  (* Definition gen_promise_list γ l := *)
  (*   own γ (gc_tup_promise_list l). *)

  Definition gen_promise_rel_pred_list γ rels preds :=
    own γ (gc_tup_rel_pred rels preds).

  Definition gen_token_used γ : iProp Σ :=
    gen_pick_out γ GTS_tok_perm.

  Definition gen_token γ : iProp Σ :=
    gen_pick_out γ (GTS_tok_both).

  Definition own_frozen_auth_promise_list γ rels preds : iProp Σ :=
    gen_promise_rel_pred_list γ
      (gP (●ML rels) ⋅ gV (●ML□ rels)) (gP (●ML preds) ⋅ gV (●ML□ preds)).

  Definition own_auth_promise_list γ rels preds : iProp Σ :=
    gen_promise_rel_pred_list γ (gPV (●ML rels)) (gPV (●ML preds)).

  Definition own_frag_promise_list γ rels preds : iProp Σ :=
    gen_promise_rel_pred_list γ (gPV (◯ML rels)) (gPV (◯ML preds)).

  Definition promise_info_for pia γs R P : Prop :=
    pia.(pi_deps_γs) = rew [λ n, ivec n _] genInG_gcd_n in γs ∧
    pia.(pi_pred) = rew [id] pred_over_Oc_genInG in P ∧
    pia.(pi_rel) = rew [id] rel_over_Oc_Ocs_genInG in R.

  (** Resources shared between [token], [used_token], and [rely]. *)
  Definition know_promise γ γs R P pia promises rels preds : iProp Σ :=
    "%pia_for" ∷ ⌜ promise_info_for pia γs R P ⌝ ∗
    "%pred_prefix" ∷ ⌜ pred_prefix_list_for' rels preds R P ⌝ ∗
    "%pia_in" ∷ ⌜ promises_lookup_at promises _ γ = Some pia ⌝ ∗
    "%prs_wf" ∷ ⌜ promises_wf Ω.(gc_map_wf) promises ⌝ ∗
    "#prs" ∷ own_promises promises. (* NOTE: There seems to be some duplication between whats's in here and the above. *)

  (** Ownership over the token and the promises for [γ]. *)
  Definition token (γ : gname) (γs : ivec n gname) R P : iProp Σ :=
    ∃ (rels : list (rel_over DS A)) preds promises pia,
      "tokenPromise" ∷ know_promise γ γs R P pia promises rels preds ∗
      "token" ∷ gen_pick_out γ GTS_tok_both ∗
      "auth_preds" ∷ own_auth_promise_list γ rels preds.

  Definition used_token (γ : gname) (γs : ivec n gname) R P : iProp Σ :=
    ∃ (rels : list (rel_over DS A)) preds ps promises pia,
      "tokenPromise" ∷ know_promise γ γs R P pia promises rels preds ∗
      own_frozen_auth_promise_list γ rels ps ∗
      "usedToken" ∷ gen_pick_out γ GTS_tok_perm.

  (** Knowledge that γ is accociated with the predicates R and P. *)
  Definition rely (γ : gname) (γs : ivec n gname) R P : iProp Σ :=
    ∃ (rels : list (rel_over DS A)) (preds : list (pred_over A)) promises pia,
      "#relyPromise" ∷ know_promise γ γs R P pia promises rels preds
      ∗ "#fragPreds" ∷ gen_promise_rel_pred_list γ (gPV (◯ML rels)) (gPV (◯ML preds)).

  Definition picked_out γ t : iProp Σ :=
    gen_pick_out γ (GTS_tok_gen_shot t).

  Definition picked_in γ (t : A → A) : iProp Σ :=
    own γ (gc_tup_pick_in DS t).

End generational_resources.

Definition rely_self `{i : !genInSelfG Σ Ω A} γ (P : pred_over A) : iProp Σ :=
  ∃ γs R, rely (i := genInSelfG_gen i) γ γs R P.

Equations True_preds_for {n} (ts : ivec n cmra) : preds_for n ts :=
| inil => hnil;
| icons t ts' => hcons True_pred (True_preds_for ts').

Lemma True_preds_for_lookup_fmap {n} (ts : ivec n cmra) i :
  hvec_lookup_fmap (True_preds_for ts) i = True_pred.
Proof.
  induction i as [|?? IH]; dependent elimination ts.
  - done.
  - apply IH.
Qed.

Lemma True_pred_rew_lookup_fmap_rew {n1 n2}
    (DS : ivec n1 cmra) (DS2 : ivec n2 cmra) i eq1 eq2 :
  hvec_lookup_fmap
    (rew [id] (hvec_fmap_eq eq1 DS DS2 eq2) in True_preds_for DS) i = True_pred.
Proof.
  destruct eq1. unfold eq_rect_r in eq2. simpl in *.
  destruct eq2. simpl.
  rewrite True_preds_for_lookup_fmap. done.
Qed.

Definition True_preds_for_id `{Ω : gGenCmras Σ}
    id : preds_for (On Ω id) (Ocs Ω id) :=
  True_preds_for (Ocs Ω id).

Lemma eq_inj {A} P (x y : A) (T1 : P x) T2 (eq : x = y) :
  rew [P] eq in T1 = rew [P] eq in T2 → T1 = T2.
Proof. destruct eq. done. Qed.

Lemma eq_rect_app_swap {A B} (f : B → Prop) (eq : B = A) (a : A) :
  (rew [λ a, a → Prop] eq in f) a ↔ f (rew <- [id] eq in a).
Proof. destruct eq. done. Qed.

Lemma rel_stronger_rew {n1 n2 A B} {DS1 : ivec n1 cmra} {DS2 : ivec n2 cmra}
    (eq1 : n1 = n2) (eq2 : A = B) eq3 (R1 R2 : rel_over DS1 A) :
  rel_stronger
    (rew [id] (rel_over_eq (DS2 := DS2) eq1 eq2 eq3) in R1)
    (rew [id] (rel_over_eq eq1 eq2 eq3)in R2) → rel_stronger R1 R2.
Proof.
  destruct eq1. destruct eq2.
  unfold eq_rect_r in eq3. simpl in eq3. destruct eq3. done.
Qed.

Lemma discrete_fun_singleton_included `{EqDecision A, finite.Finite A}
    {B : A → ucmra} {x : A} (a b : B x) :
  a ≼ b →
  (discrete_fun_singleton x a) ≼ discrete_fun_singleton x b.
Proof.
  intros incl.
  apply discrete_fun_included_spec => id.
  simpl.
  destruct (decide (id = x)) as [->|idNeq].
  2: { by rewrite !discrete_fun_lookup_singleton_ne. }
  rewrite !discrete_fun_lookup_singleton.
  done.
Qed.

Lemma discrete_fun_singleton_map_included {Σ} {i : gid Σ} {A : cmra} eq (γ : gname)
  (a b : A) :
  a ≼ b →
  ((discrete_fun_singleton i {[γ := map_unfold (cmra_transport eq a)]} : iResUR Σ)
    ≼ discrete_fun_singleton i {[γ := map_unfold (cmra_transport eq b)]}).
Proof.
  intros incl.
  apply discrete_fun_singleton_included.
  apply singleton_mono.
  apply: cmra_morphism_monotone.
  destruct eq.
  apply incl.
Qed.

Lemma iRes_singleton_included `{i : inG Σ A} (a b : A) γ :
  a ≼ b →
  (own.iRes_singleton γ a) ≼ (own.iRes_singleton γ b).
Proof. apply discrete_fun_singleton_map_included. Qed.

Lemma list_rely_self {n : nat} {DS : ivec n cmra} `{nds : ∀ (i : fin n), genInSelfG Σ Ω (DS !!! i)}
    (γs : ivec n gname) (deps_preds : preds_for n DS) :
  (∀ (i : fin n), rely_self (γs !!! i) (hvec_lookup_fmap deps_preds i)) -∗
  ∃ prs,
    (* a list of well formed promises *)
    ⌜ promises_wf (Ω.(gc_map_wf)) prs ⌝ ∗
    own_promises prs ∗
    (* contains every promise in [γs] with the pred in [deps_preds] *)
    ⌜ ∀ (idx : fin n),
      ∃ pia,
        let i := (genInG_id (@genInSelfG_gen _ _ _ (nds idx))) in
        promises_lookup_at prs i (γs !!! idx) = Some pia ∧
        let pred : pred_over (Oc Ω i) :=
          rew [λ i, i] pred_over_Oc_genInG in hvec_lookup_fmap deps_preds idx in
        pred_stronger pia.(pi_pred) pred ⌝.
Proof.
  induction n as [|n' IH].
  { iIntros "_". iExists [].
    rewrite -own_promises_empty.
    iSplit; first done.
    iSplit; first done.
    iPureIntro. intros i. inversion i. }
  iIntros "#relys".
  dependent elimination γs as [icons γ0 γs'].
  dependent elimination DS.
  simpl in deps_preds.
  dependent elimination deps_preds as [hcons p0 preds'].
  iDestruct (IH i (λ n, nds (FS n)) γs' preds' with "[]") as "(%prs & %wf2 & own & %prop)".
  { iIntros (j).
    iSpecialize ("relys" $! (FS j)).
    iApply "relys". }
  iDestruct ("relys" $! 0%fin) as "HHH".
  rewrite hvec_lookup_fmap_equation_2.
  iDestruct "HHH" as (??) "H".
  iNamed "H". iNamed "relyPromise".
  iDestruct (own_promises_merge with "own prs") as (prsM wfM val) "H";
    [done|done| ].
  iExists prsM.
  iSplit; first done.
  iSplit; first done.
  iPureIntro.
  intros n2.
  dependent elimination n2; last first.
  { (* This one is from the IH *)
    destruct (prop t) as (pia' & look & predStr).
    destruct val as (? & str & ?).
    destruct (str _ _ _ look) as (pia2 & look2 & str2).
    exists pia2.
    split; first apply look2.
    etrans; last apply predStr.
    apply str2. }
  destruct val as (? & str & str2).
  destruct (str2 _ _ _ pia_in) as (pia2 & look2 & ?).
  exists pia2.
  split; first apply look2.
  etrans; first apply H0.
  destruct pia_for as (? & -> & ?).
  done.
Qed.

Lemma rew_rel_over_True {n1 n2 A B} {DS1 : ivec n1 cmra} {DS2 : ivec n2 cmra}
    (eq1 : n1 = n2) (eq2 : A = B) eq3 (ts : trans_for n2 DS2) :
  (rew [id] (rel_over_eq eq1 eq2 eq3) in (True_rel (DS := DS1))) ts (λ a, a).
Proof.
  destruct eq1. destruct eq2.
  unfold eq_rect_r in eq3. simpl in eq3. destruct eq3.
  simpl. rewrite huncurry_curry. done.
Qed.

Lemma rew_lookup_total {A : Set} n m (γs : ivec n A) i (eq : m = n) :
  rew <- [λ n1 : nat, ivec n1 A] eq in γs !!! i =
  γs !!! rew [fin] eq in i.
Proof. destruct eq. done. Qed.

Lemma rew_True_pred {A B : cmra} (t : cmra_to_trans A) (eq : B = A) :
  (rew [pred_over] eq in True_pred) t.
Proof. destruct eq. done. Qed.

Lemma pred_prefix_list_for'_True_rew {n} {A B : cmra} {DS : ivec n cmra} {DS2 : ivec n cmra} (eq : A = B) eq2 :
  pred_prefix_list_for' (@True_rel _ DS2 _ :: nil) (True_pred :: nil)
    (rew [id] rel_over_eq eq_refl eq eq2 in (@True_rel _ DS _))
    (rew [id]
         rew [λ c : cmra, pred_over A = pred_over c] eq in eq_refl in
     (λ _ : A → A, True)).
Proof.
  destruct eq. unfold eq_rect_r in eq2. simpl in eq2. destruct eq2. simpl.
  apply pred_prefix_list_for'_True.
Qed.

Section rules_with_deps.
  Context {n : nat} {DS : ivec n cmra}
    `{gs : ∀ (i : fin n), genInSelfG Σ Ω (DS !!! i)}
    `{g : !genInDepsG Σ Ω A DS}.

  Program Definition make_pia (γs : ivec n gname) deps_preds
      (R_2 : rel_over DS A) (P_2 : pred_over A)
      (R_to_P : ∀ ts t, huncurry R_2 ts t → P_2 t)
      (real : ∀ (ts : trans_for n DS),
        preds_hold deps_preds ts → ∃ (e : A → A), huncurry R_2 ts e)
      : promise_info_at Ω _ := {|
    pi_deps_γs := (rew [λ n, ivec n _] genInG_gcd_n in γs);
    pi_deps_preds := rew [id] preds_for_genInG in deps_preds;
    pi_rel := rew [id] rel_over_Oc_Ocs_genInG in R_2;
    pi_pred := rew [id] pred_over_Oc_genInG in P_2;
  |}.
  Next Obligation.
    rewrite /rel_over_Oc_Ocs_genInG.
    intros ??????? holds.
    rewrite /pred_over_Oc_genInG.
    rewrite /Oc_genInG_eq.
    destruct genInDepsG_gen; simpl in *.
    unfold Ocs in *.
    destruct (Ω.(gc_map) genInG_id0). simpl in *.
    destruct (genInG_gcd_n0).
    destruct (genInG_gti_typ0).
    unfold eq_rect_r in *. simpl in *.
    destruct (genInG_gcd_deps0).
    simpl in *.
    eapply R_to_P.
  Qed.
  Next Obligation.
    rewrite /rel_over_Oc_Ocs_genInG.
    intros ???????.
    destruct genInDepsG_gen. simpl in *.
    unfold preds_for_genInG in *. simpl in *.
    unfold Ocs in *.
    destruct (Ω.(gc_map) genInG_id0). simpl in *.
    destruct genInG_gcd_n0.
    destruct genInG_gti_typ0.
    unfold eq_rect_r in *. simpl in *.
    destruct genInG_gcd_deps0.
    simpl in *.
    apply real.
  Qed.

  Program Definition make_true_pia (γs : ivec n gname) : promise_info_at Ω _ :=
    make_pia γs (True_preds_for DS) True_rel True_pred _ _.
  Next Obligation. intros. done. Qed.
  Next Obligation.
    intros. exists (λ a, a). rewrite huncurry_curry. done.
  Qed.

  Lemma auth_promise_list_frag γ rs ps :
    own_auth_promise_list γ rs ps
    -∗ own_auth_promise_list γ rs ps ∗ own_frag_promise_list γ rs ps.
  Proof.
    rewrite -own_op.
    unfold own_auth_promise_list.
    unfold own_frag_promise_list.
    unfold gPV.
    unfold mk_gen_pv.
    unfold gen_promise_rel_pred_list.
    unfold gc_tup_rel_pred.
    rewrite {1 2}(mono_list_auth_lb_op _ rs).
    rewrite {1 2}(mono_list_auth_lb_op _ ps).
    done.
  Qed.

  Lemma auth_promise_list_snoc γ rs ps r p :
    own_auth_promise_list γ rs ps
    ==∗ own_auth_promise_list γ (rs ++ (cons r nil)) (ps ++ (cons p nil)).
  Proof.
    rewrite /own_auth_promise_list.
    rewrite /gen_promise_rel_pred_list.
    apply own_update.
    apply prod_update; first apply prod_update; simpl; try done.
    - apply gen_pv_update.
      apply mono_list_update.
      apply prefix_app_r.
      done.
    - apply gen_pv_update.
      apply mono_list_update.
      apply prefix_app_r.
      done.
  Qed.

  Lemma Oids_genInG {n2 : nat} {A2 : cmra} {DS2 : ivec n2 cmra}
      id (g2 : genInG Σ Ω A2 DS2) i (wf : omega_wf_at Ω.(gc_map) id) :
    Oids Ω id !!! i = genInG_id g2.
  Proof.
    rewrite /omega_wf_at in wf.
    rewrite /Oids.
    destruct (gc_map Ω id) eqn:eq.
    - specialize (wf i). simpl in *.
  Abort.

  Definition promises_different_gname (prs : list (promise_info Ω)) :=
    λ γ, ∀ pi, pi ∈ prs → pi.(pi_γ) ≠ γ.

  Lemma promises_different_gname_infinite prs :
    pred_infinite (promises_different_gname prs).
  Proof.
    intros γs.
    specialize (infinite_is_fresh ((pi_γ <$> prs) ++ γs)) as [no1 no2]%not_elem_of_app .
    eexists _.
    split; last done.
    intros pi elm eq.
    apply (elem_of_list_fmap_1 pi_γ) in elm.
    simplify_eq. congruence.
  Qed.

  (* Translates between the omega based resource in [own_promise_info] and
   * [genInG] based ones. *)
  Lemma own_promise_info_own γ γs R P pia :
    promise_info_for pia γs R P →
    own_promise_info (MkPi (genInG_id genInDepsG_gen) γ pia) ⊣⊢
    (∃ Rs Ps,
      ⌜ pred_prefix_list_for' Rs Ps R P ⌝ ∗
      know_deps γ γs ∗
      own_frag_promise_list γ Rs Ps).
  Proof.
    intros (depsEq & ? & ?).
    destruct pia. simpl in *.
    unfold own_frag_promise_list.
    unfold own_promise_info.
    unfold own_promise_info_resource.
    unfold know_deps.
    unfold gen_promise_rel_pred_list.
    simpl in *.
    destruct genInDepsG_gen. simpl in *.
    unfold rel_over_Oc_Ocs_genInG in *.
    unfold pred_over_Oc_genInG in *.
    unfold gen_promise_rel_pred_list.
    setoid_rewrite own_gen_cmra_data_to_inG.
    unfold genInG_inG.
    simpl.
    unfold omega_genInG_cmra_eq.
    unfold generational_cmraR_transp.
    unfold Ocs in *.
    unfold Oeq.
    unfold Ogid.
    simpl in *.
    unfold Oown.
    setoid_rewrite <- own_op.
    simpl in *.
    destruct (Ω.(gc_map) genInG_id0). simpl in *.
    destruct genInG_gcd_n0.
    destruct genInG_gti_typ0.
    unfold eq_ind_r in *.
    unfold eq_rect_r in *. simpl in *.
    destruct genInG_gcd_deps0. simpl.
    repeat f_equiv; try done.
    rewrite depsEq.
    done.
  Qed.

  Lemma own_gen_alloc (a : A) γs (deps_preds : preds_for n DS) :
    ✓ a →
    (* For every dependency we own a [rely_self]. *)
    (∀ i, rely_self (γs !!! i) (hvec_lookup_fmap deps_preds i)) -∗
    |==> ∃ γ, gen_own γ a ∗ token γ γs True_rel (λ _, True%type).
  Proof.
    iIntros (Hv) "relys".
    rewrite /gen_own /token.
    iDestruct (list_rely_self with "relys") as (prs wf) "(ownPrs & %allDeps)".
    (* We need to know that the new ghost name makes the new promise different
     * from all existing promises. We "overapproximate" this by requiring the
     * new gname to be different from the gname for any existing promise. *)
    iMod (own_alloc_strong
      (gc_tup_deps A DS (ivec_to_list γs) ⋅
       gc_tup_elem DS a ⋅
       gc_tup_pick_out DS GTS_tok_both ⋅
       gc_tup_rel_pred
         (gPV (●ML (True_rel :: []) ⋅ ◯ML (True_rel :: [])))
         (gPV (●ML (True_pred :: []) ⋅ ◯ML (True_pred :: [])))
       ) (promises_different_gname prs)) as (γ pHolds) "[[[OD OA] A'] B]".
    { apply promises_different_gname_infinite. }
    { split; first split; simpl; try done.
      - rewrite ucmra_unit_left_id.
        apply gen_pv_valid.
        apply mono_list_both_valid.
        exists []. done.
      - rewrite ucmra_unit_left_id.
        apply gen_pv_valid.
        apply mono_list_both_valid.
        exists []. done. }
    iDestruct "B" as "[B1 B2]".
    iExists γ.
    iModIntro. iFrame "OA".
    set (pia := make_true_pia γs).
    iExists ((_) :: nil), ((_) :: nil), ((MkPi _ γ pia) :: prs), pia.
    iFrame "B1".
    iFrame "A'".
    rewrite /know_promise.
    iSplit; first done.
    iSplit. { iPureIntro. apply pred_prefix_list_for'_True. }
    iSplit. { iPureIntro. apply promises_lookup_at_cons. }
    iSplit.
    { (* Show that the promises are well-formed. *)
      iPureIntro. split; last done.
      simpl.
      split.
      - intros pi2 elem.
        right. simpl. apply PositiveOrder.neq_sym.
        apply pHolds. done.
      - intros i. simpl in i.
        destruct (allDeps (rew <- genInG_gcd_n in i)) as (pia' & look & predStr).
        exists (MkPi _ (γs !!! rew <- [fin] genInG_gcd_n in i) pia').
        simpl.
        split. { apply promises_lookup_at_Some. done. }
        unfold promise_satisfy_dep. simpl.
        split.
        { rewrite -rew_lookup_total. unfold eq_rect_r.
          rewrite eq_sym_involutive. done. }
        unfold Oids.
        specialize (genInDepsG_eqs (rew On_genInG in i)) as idEqs.
        assert (Oids Ω (genInG_id genInDepsG_gen) !!! i =
          genInG_id (genInSelfG_gen (gs (rew <- [fin] genInG_gcd_n in i)))) as eq.
        { rewrite rew_opp_r in idEqs.
          rewrite -idEqs. done. }
        exists eq.
        intros ??. simpl. clear.
        unfold lookup_fmap_Ocs.
        destruct eq. simpl. clear.
        rewrite True_pred_rew_lookup_fmap_rew.
        apply rew_True_pred. }
    unfold own_promises.
    rewrite big_sepL_cons.
    iFrame "ownPrs".
    iApply own_promise_info_own; first done.
    iExists (True_rel :: nil).
    iExists (True_pred :: nil).
    iFrame.
    iPureIntro. apply pred_prefix_list_for'_True.
  Qed.

  Lemma gen_token_split γ :
    gen_pick_out γ GTS_tok_both ⊣⊢
      gen_pick_out γ GTS_tok_perm ∗
      gen_pick_out γ GTS_tok_gen.
  Proof. rewrite -own_op. done. Qed.

  Lemma gen_picked_in_agree γ (f f' : A → A) :
    gen_picked_in γ f -∗ gen_picked_in γ f' -∗ ⌜ f = f' ⌝.
  Proof.
    iIntros "A B".
    iDestruct (own_valid_2 with "A B") as "val".
    iDestruct (prod_valid_1st with "val") as %val.
    iPureIntro.
    rewrite Some_valid in val.
    apply (to_agree_op_inv_L (A := leibnizO (A → A))) in val.
    done.
  Qed.

  (** Strengthen a promise. *)
  Lemma token_strengthen_promise
      γ γs (deps_preds : preds_for n DS)
      (R_1 R_2 : rel_over DS A) (P_1 P_2 : (A → A) → Prop) :
    (* The new relation is stronger. *)
    (∀ (ts : trans_for n DS) (t : A → A),
       huncurry R_2 ts t → huncurry R_1 ts t) →
    (* The new predicate is stronger. *)
    (∀ t, P_2 t → P_1 t) →
    (* The new relation implies the new predicate. *)
    (∀ ts t, huncurry R_2 ts t → P_2 t) →
    (* Evidence that the promise is realizeable. *)
    (∀ (ts : trans_for n DS),
      preds_hold deps_preds ts → ∃ (e : A → A), huncurry R_2 ts e) →
    (* For every dependency we own a [rely_self]. *)
    (∀ (i : fin n), rely_self (γs !!! i) (hvec_lookup_fmap deps_preds i)) -∗
    token γ γs R_1 P_1 ==∗
    token γ γs R_2 P_2.
  Proof.
    iIntros (relStronger predStronger relToPred evidence) "relys".
    iDestruct (list_rely_self with "relys") as (depPrs wf) "(ownPrs & %allDeps)".
    iNamed 1.
    iNamed "tokenPromise".
    iDestruct (own_promises_merge with "prs ownPrs") as (prs2 ? val) "O"; [done|done| ].
    (* For each dependency we have a rely and that rely will have a list of
     * promises. We need to merge all of these promises and then create an
     * updated promise for the token.*)
    rewrite /token.
    set (pia2 := make_pia γs deps_preds R_2 P_2 relToPred evidence).
    iDestruct (big_sepL_elem_of with "prs") as "H".
    { eapply promises_lookup_at_Some. done. }
    iDestruct (own_promise_info_own with "H") as (???) "(deps & _)"; first done.
    iExists (rels ++ (R_2 :: nil)).
    iExists (preds ++ (P_2 :: nil)).
    iExists (promises_list_update _ γ pia2 prs2).
    iExists pia2.
    iFrame "token".
    iMod (auth_promise_list_snoc γ with "auth_preds") as "a".
    iDestruct (auth_promise_list_frag with "a") as "[$ frag_preds]".
    iModIntro.
    unfold know_promise.
    iSplit; first done.
    iSplit. { iPureIntro. eapply pred_prefix_list_for'_grow; done. }
    iSplit.
    { iPureIntro.
      destruct val as (_ & str & ?).
      specialize (str _ _ _ pia_in) as (pia3 & ? & ?).
      eapply promises_lookup_update.
      done. }
    iSplit.
    { iPureIntro. admit. (* show wf *) }
    unfold own_promises.
    rewrite 3!big_sepL_forall_elem_of.
    iIntros (? [?| ->]%promises_list_update_elem_of).
    - iApply "O". done.
    - iApply own_promise_info_own; first done.
      iExists _, _.
      iFrame "frag_preds deps".
      iPureIntro. eapply pred_prefix_list_for'_grow; done.
  Admitted.

  Lemma token_pick γ γs (R : rel_over DS A) P (ts : trans_for n DS) t :
    huncurry R ts t →
    (∀ i, picked_out (i := genInSelfG_gen (gs i)) (γs !!! i) (hvec_lookup_fmap ts i)) -∗
    token γ γs R P -∗ |==>
    used_token γ γs R P ∗ picked_out γ t.
  Proof.
  Admitted.

  Lemma token_to_rely γ γs (R : rel_over DS A) P :
    token γ γs R P ⊢ rely γ γs R P.
  Proof.
    iNamed 1.
  Admitted.

  (* Lemma know_promise_extract_frag γ γs R P pia promises rels *)
  (*     (preds : list (pred_over A)) : *)
  (*   know_promise γ γs R P pia promises rels preds ⊢ *)
  (*   ∃ rels' preds', *)
  (*   gen_promise_rel_pred_list γ (gPV (◯ML rels')) (gPV (◯ML preds')). *)
  (* Proof. *)
  (*   iNamed 1. *)
  (*   unfold own_promises. *)
  (*   apply promises_lookup_at_Some in pia_in as elem. *)
  (*   iSpecialize ("prs" $! _ elem). *)
  (*   simpl. *)
  (*   iDestruct "prs" as (eq ????) "-#prs". *)
  (*   rewrite /gen_promise_rel_pred_list own.own_eq /own.own_def. *)
  (*   rewrite /own.iRes_singleton. simpl. *)
  (*   iExists (rew <- rel_over_Oc_Ocs_genInG in Rs). *)
  (*   iExists (rew <- pred_over_Oc_genInG in Ps). *)
  (*   iStopProof. *)
  (*   f_equiv. *)
  (*   simpl. *)
  (*   rewrite /own.inG_unfold. *)
  (*   rewrite /map_unfold. *)
  (*   simpl. *)
  (* Qed. *)

  Lemma token_rely_combine_pred γ γs R1 P1 R2 P2 :
    token γ γs R1 P1 -∗ rely γ γs R2 P2 -∗ ⌜ rel_stronger R1 R2 ⌝.
  Proof.
    iNamed 1. iNamed "tokenPromise".
    iNamed 1. iDestruct "relyPromise" as "(? & %relyPredPrefix & ?)".
    iDestruct (own_valid_2 with "auth_preds fragPreds") as "val".
    iDestruct (prod_valid_5th with "val") as "%val".
    iPureIntro.
    move: val.
    rewrite gen_pv_op. rewrite gen_pv_valid.
    intros prefix%mono_list_both_valid_L.
    destruct pred_prefix as [? ?].
    destruct relyPredPrefix as [? ?].
    eapply pred_prefix_list_for_prefix_of; try done.
  Admitted.

  Lemma know_deps_agree γ γs1 γs2 :
    know_deps γ γs1 -∗
    know_deps γ γs2 -∗
    ⌜ γs1 = γs2 ⌝.
  Proof.
    iIntros "A B".
    iDestruct (own_valid_2 with "A B") as "hv".
    iDestruct (prod_valid_4th with "hv") as "%val".
    iPureIntro.
    rewrite Some_valid in val.
    rewrite to_agree_op_valid_L in val.
    apply ivec_to_list_inj.
    apply val.
  Qed.

  Lemma know_promise_combine γ γs1 R1 P1 pia1 promises1 all1 preds1
    γs2 R2 P2 pia2 promises2 all2 preds2 :
    know_promise γ γs1 R1 P1 pia1 promises1 all1 preds1 -∗
    know_promise γ γs2 R2 P2 pia2 promises2 all2 preds2 -∗
    ⌜ γs1 = γs2 ∧
      ((rel_stronger R1 R2 ∧ pred_stronger P1 P2) ∨
       (rel_stronger R2 R1 ∧ pred_stronger P2 P1)) ⌝.
  Proof.
    iNamed 1.
    destruct pia_for as (γs_eq & pred_eq & rel_eq).
    iDestruct 1 as (inf ???) "#prs2".
    destruct inf as (depsEq2 & pred_eq2 & rel_eq2).
    iDestruct (own_promises_overlap with "prs prs2") as %lap.
    iPureIntro.
    eassert (_ ∨ _) as [str|str]. { eapply lap; done. }
    - destruct str as (depsEq & rStr & pStr).
      split. {
        rewrite depsEq depsEq2 in γs_eq. clear -γs_eq.
        rewrite /eq_rect_r in γs_eq.
        apply (eq_inj (λ y : nat, ivec y gname)) in γs_eq.
        done. }
      left.
      rewrite rel_eq rel_eq2 in rStr.
      split.
      { clear -rStr.
        rewrite /rel_over_Oc_Ocs_genInG in rStr.
        destruct genInDepsG_gen. simpl in *.
        unfold Ocs in *.
        eapply rel_stronger_rew.
        apply rStr. }
      rewrite pred_eq pred_eq2 in pStr.
      clear -pStr.
      rewrite /pred_over_Oc_genInG in pStr.
      destruct genInDepsG_gen. simpl in *.
      rewrite /Oc_genInG_eq in pStr. simpl in *.
      destruct genInG_gti_typ0.
      apply pStr.
    - destruct str as (depsEq & rStr & pStr).
      split. {
        rewrite -depsEq depsEq2 in γs_eq. clear -γs_eq.
        rewrite /eq_rect_r in γs_eq.
        apply (eq_inj (λ y : nat, ivec y gname)) in γs_eq.
        done. }
      right.
      rewrite rel_eq rel_eq2 in rStr.
      split.
      { clear -rStr.
        rewrite /rel_over_Oc_Ocs_genInG in rStr.
        destruct genInDepsG_gen. simpl in *.
        unfold Ocs in *.
        eapply rel_stronger_rew.
        apply rStr. }
      rewrite pred_eq pred_eq2 in pStr.
      rewrite /pred_over_Oc_genInG in pStr.
      clear -pStr.
      destruct genInDepsG_gen. simpl in *.
      rewrite /Oc_genInG_eq in pStr. simpl in *.
      destruct genInG_gti_typ0.
      apply pStr.
  Qed.

  Lemma rely_combine γ γs1 γs2 R1 P1 R2 P2 :
    rely γ γs1 R1 P1 -∗
    rely γ γs2 R2 P2 -∗
    ⌜ γs1 = γs2 ⌝ ∗
    ⌜ (rel_stronger R1 R2 ∧ pred_stronger P1 P2) ∨
      (rel_stronger R2 R1 ∧ pred_stronger P2 P1) ⌝.
  Proof.
    iNamed 1.
    iDestruct 1 as (????) "(relyPromise2 & ?)".
    iDestruct (know_promise_combine with "relyPromise relyPromise2") as "$".
  Qed.

End rules_with_deps.

Section nextgen_assertion_rules.
  (* Rules about the nextgen modality. *)
  Context {n : nat} {DS : ivec n cmra} `{!genInG Σ Ω A DS}.

  Lemma Oown_build_trans_next_gen i γ (m : generational_cmraR _ _) picks
      `{!GenTrans (build_trans picks)} :
    transmap_valid picks →
    Oown i γ m ⊢ ⚡={build_trans picks}=> Oown i γ (
      gen_cmra_trans (
        (default (λ a, a) (picks _ !! γ))
      ) m).
  Proof.
    iIntros (?) "H".
    unfold Oown.
    iEval (rewrite own.own_eq) in "H".
    rewrite /own.own_def.
    iModIntro.
    iEval (rewrite own.own_eq).
    rewrite /own.own_def.
    simpl.
    rewrite build_trans_singleton_alt; try done.
  Qed.

  Lemma own_build_trans_next_gen γ (m : generational_cmraR A DS) picks
      `{!GenTrans (build_trans picks)} :
    transmap_valid picks →
    own γ m ⊢ ⚡={build_trans picks}=> own γ (
      gen_cmra_trans (
        rew <- [cmra_to_trans] Oc_genInG_eq in (default (λ a, a) (picks _ !! γ))
      ) m).
  Proof.
    iIntros (?) "H".
    iEval (rewrite own.own_eq) in "H".
    rewrite /own.own_def.
    iModIntro.
    iEval (rewrite own.own_eq).
    rewrite /own.own_def.
    simpl.
    rewrite build_trans_singleton; [ |done|done].
    simpl.
    rewrite /gen_cmra_trans. simpl.
    done.
  Qed.

  Lemma own_promise_info_nextgen picks pi `{!GenTrans (build_trans picks)} :
    transmap_valid picks →
    own_promise_info pi ⊢ ⚡={build_trans picks}=> own_promise_info pi.
  Proof.
    iIntros (val). iDestruct 1 as (???) "O".
    iDestruct (Oown_build_trans_next_gen with "O") as "O"; first done.
    iModIntro.
    iExists _, _. iSplit; first done.
    rewrite gen_cmra_trans_apply. simpl.
    iStopProof.
    unfold own_promise_info_resource.
    unfold Oown.
    f_equiv. simpl.
    simpl.
    rewrite 5!pair_included.
    split_and!; try done. apply ucmra_unit_least.
  Qed.

  (* NOTE: This doesn't really work as an instance since TC search can't find
   * the [val] we need. This could prop. be fixed by keeping this fact in a TC. *)
  Global Instance into_bnextgen_own_promise_info picks
      `{!GenTrans (build_trans picks)} (val : transmap_valid picks) :
    ∀ pi, IntoBnextgen (build_trans picks) (own_promise_info pi) (own_promise_info pi).
  Proof.
    intros pi.
    rewrite /IntoBnextgen.
    iApply (own_promise_info_nextgen).
    done.
  Qed.

  Lemma own_promises_nextgen picks ps `{!GenTrans (build_trans picks)} :
    transmap_valid picks →
    own_promises ps ⊢ ⚡={build_trans picks}=> own_promises ps.
  Proof.
    iIntros (val) "#prs".
    rewrite /own_promises.
    rewrite big_sepL_forall_elem_of.
    specialize (into_bnextgen_own_promise_info _ val) as H.
    iModIntro.
    done.
  Qed.

  Lemma own_build_trans_next_gen_picked_in γ (m : generational_cmraR A DS) picks
      `{!GenTrans (build_trans picks)} :
    transmap_valid picks →
    own γ m ⊢ ⚡={build_trans picks}=>
      gen_picked_in γ (rew <- [cmra_to_trans] Oc_genInG_eq in (default (λ a, a) (picks _ !! γ)))
    .
  Proof.
    iIntros (?) "H".
    iEval (rewrite own.own_eq) in "H".
    rewrite /own.own_def.
    iModIntro.
    rewrite /gen_picked_in own.own_eq /own.own_def.
    simpl.
    rewrite build_trans_singleton; [ |done|done].
    simpl.
    rewrite /gen_cmra_trans. simpl.
    iStopProof.
    f_equiv.
    simpl.
    apply iRes_singleton_included.
    rewrite !pair_included.
    split_and!; try apply: ucmra_unit_least. done.
  Qed.

  Lemma know_deps_nextgen γ γs :
    know_deps γ γs ⊢ ⚡==> know_deps γ γs.
  Proof.
    rewrite /know_deps.
    iIntros "H".
    iExists (λ i, ∅), [].
    iSplitL "". { iApply own_picks_empty. }
    iSplitL "". { iApply own_promises_empty. }
    iSplit; first done.
    iIntros (full_picks ?) "_ %sub".
    iDestruct (own_build_trans_next_gen with "H") as "H"; first done.
    iModIntro.
    iStopProof.
    f_equiv. simpl.
    rewrite !pair_included.
    split_and!; try done.
    apply ucmra_unit_least.
  Qed.

  Lemma token_nextgen γ γs (R : rel_over DS A) P :
    used_token γ γs R P ⊢ ⚡==> token γ γs R P.
  Proof.
    iNamed 1. iNamed "tokenPromise".

    iExists (λ i, ∅), [].
    iSplitL "". { iApply own_picks_empty. }
    iSplitL "". { iApply own_promises_empty. }
    iSplit; first done.
    iIntros (full_picks ? ? ?).
    (* iEval (rewrite own.own_eq) in "own". *)
    (* rewrite /own.own_def. *)
    (* iModIntro. *)
  Admitted.
  (*   iDestruct (uPred_own_resp_omega _ _ with "own") as (to) "(%cond & own)". *)
  (*   { done. } *)
  (*   simpl in cond. *)
  (*   destruct cond as (t & -> & cond). *)
  (*   iExists t. *)
  (*   iSplit; first done. *)
  (*   simpl. *)
  (*   rewrite /gen_picked_in. *)
  (*   rewrite -own_op. *)
  (*   rewrite own.own_eq. *)
  (*   iFrame "own". *)
  (* Qed. *)

  Lemma own_gen_cmra_split_picked_in γ a b c d e f :
    own γ (a, b, c, d, e, f) ⊣⊢ own γ (a, ε, ε, ε, ε, ε) ∗ own γ (ε, b, c, d, e, f).
   Proof.
     rewrite -own_op.
     f_equiv.
     rewrite -!pair_op.
     rewrite prod_6_equiv.
     unfold gen_pvR in *.
     split_and!;
       rewrite ?ucmra_unit_left_id;
       rewrite ?ucmra_unit_right_id; done.
  Qed.

  (* TODO: Prove this lemma. *)
  Lemma rely_nextgen γ γs (R : rel_over DS A) (P : pred_over A)
      `{gs : ∀ (i : fin n), genInSelfG Σ Ω (DS !!! i)} :
    rely γ γs R P
    ⊢ ⚡==>
      rely γ γs R P ∗
      ∃ (t : A → A) (ts : trans_for n DS),
        ⌜ huncurry R ts t ∧ (* The transformations satisfy the promise *)
          P t ⌝ ∗ (* For convenience we also give this directly *)
        gen_picked_in γ t ∗
        (* The transformations for the dependencies are the "right" ones *)
        (∀ i, gen_picked_in (i := genInSelfG_gen (gs i)) (γs !!! i) (hvec_lookup_fmap ts i)).
  Proof.
    rewrite /rely.
    iNamed 1. iNamed "relyPromise".
    destruct pia_for as (γs_eq & pred_eq & rel_eq).
    rewrite /nextgen.
    iExists (λ i, ∅), promises.
    iSplitL ""; first iApply own_picks_empty.
    iFrame "prs".
    iSplit; first done.
    iIntros (full_picks val resp _).
    (* iDestruct (own_build_trans_next_gen with "fragPreds") as "rely_deps'"; first done. *)
    iDestruct (own_build_trans_next_gen with "fragPreds") as "-#frag_preds'"; first done.
    iDestruct (own_promises_nextgen with "prs") as "prs'"; first done.
    iModIntro.
    edestruct (transmap_resp_promises_lookup_at)
      as (ts & t & look & ? & relHolds); [done|done| ].
    simpl in *.
    rewrite look.
    iDestruct (own_gen_cmra_split_picked_in with "frag_preds'") as "[picked_in frag_preds']".
    iSplit.
    - iExists rels, preds, promises, pia.
      iSplit.
      { do 4 (iSplit; first done).
        iFrame "prs'". }
      iFrame "frag_preds'".
    - iExists (rew <- [cmra_to_trans] Oc_genInG_eq in t).
      iExists (rew <- [id] trans_for_genInG in ts).
      simpl.
      iFrame "picked_in".
      iSplit; first iPureIntro.
      { pose proof (pi_rel_to_pred pia _ _ relHolds) as predHolds.
        rewrite rel_eq in relHolds.
        rewrite pred_eq in predHolds.
        clear -relHolds predHolds.
        rewrite /rel_over_Oc_Ocs_genInG in relHolds.
        rewrite /rel_over_eq in relHolds.
        rewrite /pred_over_Oc_genInG in predHolds.
        rewrite /Oc_genInG_eq in predHolds.
        rewrite /trans_for_genInG.
        rewrite /Oc_genInG_eq.
        rewrite /hvec_fmap_eq.
        destruct genInG0. simpl in *.
        unfold Ocs in *.
        destruct (gc_map Ω genInG_id0). simpl in *.
        destruct genInG_gcd_n0. simpl in *.
        destruct genInG_gti_typ0.
        unfold eq_rect_r in *. simpl in *.
        destruct genInG_gcd_deps0. simpl in *.
        split.
        + apply relHolds.
        + apply predHolds. }
      admit.
  Admitted.

End nextgen_assertion_rules.

Equations forall_fin_2 (P : fin 2 → Type) : P 0%fin * P 1%fin → ∀ (i : fin 2), P i :=
| P, p, 0%fin => fst p
| P, p, 1%fin => snd p.

(* This is a hacky way to find all the [genInSelfG] instances when there are
exactly two dependencies. It would be nicer with a solution that could iterate
over all the dependencies during type class resolution (maybe inspired by
[TCForall] for lists). *)
Global Instance genInG_forall_2 {Σ n m} {DS1 : ivec n cmra} {DS2 : ivec m cmra}
  `{!genInG Σ Ω A DS1} `{!genInG Σ Ω B DS2} :
  ∀ (i : fin 2), genInSelfG Σ Ω ([A; B]%IL !!! i).
Proof.
  intros i.
  dependent elimination i.
  dependent elimination t.
  dependent elimination t.
  (* apply forall_fin_2. *)
  (* split. *)
  (* - apply (GenInG2 _ _ _ n DS1 _). *)
  (* - apply (GenInG2 _ _ _ m DS2 _). *)
Qed.

Section test.
  Context `{max_i : !genInG Σ Ω max_natR inil}.
  Context `{i : !genInDepsG Σ Ω max_natR [max_natR; max_natR] }.

  Definition a_rely :=
    rely (1%positive) [2%positive; 3%positive] (λ Ta Tb Ts, Ta = Ts ∧ Tb = Ts) (λ _, True).

  Section test.
    Variables (A : cmra) (B : cmra) (T1 : A → A) (T2 : B → B)
      (P1 : (A → A) → Prop) (P2 : (B → B) → Prop).

    Definition TS : trans_for _ [A; B] := [T1; T2]%HV.
    Definition PS : preds_for _ [A; B] := [P1; P2].
    Compute (preds_hold (DS := [A; B]) PS TS).

    Context `{!genInG Σ Ω A [] }.
    Context `{!genInG Σ Ω B [] }.
    Context `{!genInDepsG Σ Ω A [A; B] }.

    Lemma foo2 (γ : gname) (γs : ivec 2 gname) : True.
    Proof.
      pose proof (token_strengthen_promise γ γs PS) as st.
      rewrite /rel_over in st.
      rewrite /cmra_to_trans in st.
      simpl in st.
    Abort.

  End test.

  Definition a_rel (Ta : max_natR → max_natR) Tb Ts :=
    Ta = Ts ∧ Tb = Ts.

End test.
