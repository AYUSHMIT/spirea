From Equations Require Import Equations.

From iris.algebra Require Import functions gmap agree excl csum max_prefix_list.
From iris.proofmode Require Import classes tactics.
From iris.base_logic.lib Require Export iprop own invariants.
From iris.prelude Require Import options.

From iris_named_props Require Import named_props.

From self Require Import hvec extra basic_nextgen_modality gen_trans
  gen_single_shot gen_pv.

Import EqNotations. (* Get the [rew] notation. *)
Import uPred.

#[global] Instance eqdecision_eqdec a : EqDecision a → EqDec a.
Proof. done. Qed.

(** A copy of [option] to work arround universe inconsistencies that arrise if
we use [option]. *)
Inductive option2 (A : Type) : Type :=
  | Some2 : A -> option2 A
  | None2 : option2 A.

Arguments Some2 {A} a.
Arguments None2 {A}.

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

  (* Definition rel_over_typ {n} (DS : ivec n Type) (A : Type) := *)
  (*   iimpl id ((λ a, a → a) <$> DS) ((A → A) → Prop). *)

  (* (* An example to demonstrate [rel_over_typ]. This results in the type: *)
  (*    [(bool → bool) → (() → ()) → (nat → nat) → Prop] *) *)
  (* Compute (rel_over_typ [bool : Type; unit : Type] nat). *)

  (** A relation over transformations between the cameras in [DS and [A]. *)
  Definition rel_over {n} (DS : ivec n cmra) (A : cmra) :=
    iimpl id (cmra_to_trans <$> DS) ((A → A) → Prop).

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

End cmra_map_transport.

(* Resources for generational ghost state. *)

(* Resource algebra for the dependency relation in promises. *)
(* Q: Do we need to store both R and P or only R?? *)
Section dependency_relation_cmra.
  Context {n : nat}.

  (* Canonical Structure pred_over_tyO (A : Type) (DS : ivec n Type) := *)
  (*   leibnizO (rel_over_typ DS A). *)
  Canonical Structure pred_overO (A : cmra) (DS : ivec n cmra) :=
    leibnizO (rel_over DS A).

  (* Definition promises (A : Type) (DS : ivec n Type) := *)
  (*   max_prefix_list (rel_over_typ DS A). *)
  Definition promisesR (A : cmra) (DS : ivec n cmra) :=
    max_prefix_listR (pred_overO A DS).

  Definition promisesUR (A : cmra) (DS : ivec n cmra) :=
    max_prefix_listUR (rel_over DS A).

  (* Authorative promises. *)
  Definition auth_promises {A : cmra} {DS : ivec n cmra}
    (ps : list (rel_over DS A)) : auth (max_prefix_list (rel_over DS A)) :=
    ● (to_max_prefix_list ps).
  (* Definition auth_promises_ty {A : Type} {DS : ivec n Type} *)
  (*   (ps : list (rel_over_typ DS A)) : auth (promises A DS) := *)
  (*   ● (to_max_prefix_list ps). *)

  (* Fragmental promises. *)
  (* Definition frag_promises {A : Type} {DS : ivec n Type} *)
  (*   (ps : list (rel_over_typ DS A)) : auth (promises A DS) := *)
  (*   ◯ (to_max_prefix_list ps). *)

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

  Definition rel_weaker (R1 R2 : rel_over DS A) := rel_stronger R2 R1.

  Definition pred_stronger (P1 P2 : (A → A) → Prop) :=
    ∀ (t : A → A), P1 t → P2 t.

  Definition rel_implies_pred R P : Prop :=
    ∀ (ts : trans_for n DS) (t : A → A), huncurry R ts t → P t.

  (* Notation preds_for n ls := (hvec pred_over n ls). *)

  Definition pred_prefix_list_for (all : list (rel_over DS A)) R :=
    (* The given promise [R] is the last promise out of all promises. *)
    last all = Some R ∧
    (* The list of promises increases in strength. *)
    ∀ i j (Ri Rj : rel_over DS A),
      i ≤ j → all !! i = Some Ri → all !! j = Some Rj → rel_weaker Ri Rj.

  (* Includes [P] as well. *)
  Definition pred_prefix_list_for' (all : list (rel_over DS A)) R P :=
    pred_prefix_list_for all R ∧ rel_implies_pred R P.

  Lemma pred_prefix_list_for_singleton p :
    pred_prefix_list_for (p :: []) p.
  Proof.
    split; first done.
    intros ????? [-> ->]%list_lookup_singleton_Some
      [-> ->]%list_lookup_singleton_Some.
    intros ??. done.
  Qed.

  Lemma pred_prefix_list_for'_True :
    pred_prefix_list_for' (True_rel :: []) True_rel (λ _ : A → A, True).
  Proof.
    rewrite /pred_prefix_list_for'.
    split; [apply pred_prefix_list_for_singleton | done].
  Qed.

  Lemma pred_prefix_list_for_prefix_of Rs1 Rs2 R1 R2:
    pred_prefix_list_for Rs1 R1 →
    pred_prefix_list_for Rs2 R2 →
    Rs1 `prefix_of` Rs2 →
    rel_stronger R2 R1.
  Proof.
    intros PP1 PP2 pref.
    destruct PP1 as [isLast1 _].
    destruct PP2 as [isLast2 weaker].
    rewrite last_lookup in isLast1.
    rewrite last_lookup in isLast2.
    eapply weaker; last done.
    - apply le_pred. apply prefix_length. eassumption.
    - eapply prefix_lookup; done.
  Qed.

End dependency_relation_extra.

(* Definition generational_cmra {n} A (DS : ivec n Type) : Type := *)
(*   option (agree (A → A)) * (* Agreement on transformation into generation *) *)
(*   GTS (A → A) * (* Facilitates choice of transformation out of generation *) *)
(*   option A * (* Ownership over A *) *)
(*   option (agree (list gname)) * (* Gname of dependencies - we don't need to *)
(*                                  * store their [gid] as that is static. *) *)
(*   gen_pv (auth (promises A DS)) (* List of promises *). *)

(* Notation for [prodR] as the product below would otherwise get horrible to
 * write. *)
Local Infix "*R*" := prodR (at level 50, left associativity).

Definition generational_cmraR {n} (A : cmra) (DS : ivec n cmra) : cmra :=
  optionR (agreeR (leibnizO (A → A))) *R*
  GTSR (A → A) *R*
  optionR A *R*
  optionR (agreeR (leibnizO (list gname))) *R*
  gen_pvR (authR (promisesR A DS)).

Local Infix "*M*" := prod_map (at level 50, left associativity).

(* The generational transformation function for the encoding of each ownership
over a generational camera. *)
Definition gen_cmra_trans {n} {A : cmra} {DS : ivec n cmra}
    (f : A → A) : generational_cmraR A DS → generational_cmraR A DS :=
  (const (Some (to_agree f)) : _ → optionR (agreeR (leibnizO (A → A)))) *M*
  (GTS_floor : (GTSR (A → A)) → (GTSR (A → A))) *M*
  (fmap f : optionR A → optionR A) *M*
  id *M*
  gen_pv_trans.

(* Working with the 5-tuple is sometimes annoying. Then these lemmas help. *)
Lemma prod_valid_1st {Σ}
  {A B C D E : cmra} (a : A) (b : B) (c : C) (d : D) (e : E) f g h i j :
  ✓ ((a, b, c, d, e) ⋅ (f, g, h, i, j)) ⊢@{iProp Σ} ✓ (a ⋅ f).
Proof. rewrite 4!prod_validI. simpl. iIntros "[[[[$ _] _] _] _]". Qed.

Lemma prod_valid_2st {Σ}
  {A B C D E : cmra} (a : A) (b : B) (c : C) (d : D) (e : E) f g h i j :
  ✓ ((a, b, c, d, e) ⋅ (f, g, h, i, j)) ⊢@{iProp Σ} ✓ (b ⋅ g).
Proof. rewrite 4!prod_validI. simpl. iIntros "[[[[_ $] _] _] _]". Qed.

Lemma prod_valid_3th {Σ}
  {A B C D E : cmra} (a : A) (b : B) (c : C) (d : D) (e : E) f g h i j :
  ✓ ((a, b, c, d, e) ⋅ (f, g, h, i, j)) ⊢@{iProp Σ} ✓ (c ⋅ h).
Proof. rewrite 4!prod_validI. simpl. iIntros "[[[_ $] _] _]". Qed.

Lemma prod_valid_4th {Σ}
  {A B C D E : cmra} (a : A) (b : B) (c : C) (d : D) (e : E) f g h i j :
  ✓ ((a, b, c, d, e) ⋅ (f, g, h, i, j)) ⊢@{iProp Σ} ✓ (d ⋅ i).
Proof. rewrite 4!prod_validI. iIntros "[[_ $] _]". Qed.

Lemma prod_valid_5th {Σ}
  {A B C D E : cmra} (a : A) (b : B) (c : C) (d : D) (e : E) f g h i j :
  ✓ ((a, b, c, d, e) ⋅ (f, g, h, i, j)) ⊢@{iProp Σ} ✓ (e ⋅ j).
Proof. rewrite 4!prod_validI. iIntros "[_ $]". Qed.

(* Constructors for each of the elements in the pair. *)

Definition gc_tup_pick_in {n A} (DS : ivec n cmra) pick_in : generational_cmraR A DS :=
 (Some (to_agree (pick_in)), ε, ε, ε, ε).

Definition gc_tup_pick_out {A n} (DS : ivec n cmra) pick_out : generational_cmraR A DS :=
 (ε, pick_out, ε, ε, ε).

Definition gc_tup_elem {A n} (DS : ivec n cmra) a : generational_cmraR A DS :=
 (ε, ε, Some a, ε, ε).

Definition gc_tup_deps {n} A (DS : ivec n cmra) deps : generational_cmraR A DS :=
 (ε, ε, ε, Some (to_agree deps), ε).

Definition gc_tup_promise_list {n A} {DS : ivec n cmra} l : generational_cmraR A DS :=
 (ε, ε, ε, ε, l).

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
      (Some (to_agree f), GTS_floor a.1.1.1.2, f <$> a.1.1.2, a.1.2, gen_pv_trans a.2).
  Proof. done. Qed.

End gen_cmra.

(** For every entry in [Ω] we store this record of information. The equality
 * [gcd_cmra_eq] is the "canonical" equality we will use to show that the resource
 * [R Σ i] has the proper form. Using this equality is necesarry as we
 * otherwise end up with different equalities of this form that we then do not
 * know to be equal. *)
Record gen_cmra_data (Σ : gFunctors) (i : gid Σ) := {
  gcd_cmra : cmra;
  gcd_n : nat;
  gcd_deps : ivec gcd_n cmra;
  gcd_deps_ids : ivec gcd_n (gid Σ);
  gcd_cmra_eq : generational_cmraR gcd_cmra gcd_deps = R Σ i;
}.

Arguments gcd_cmra {_} {_}.
Arguments gcd_n {_} {_}.
Arguments gcd_deps {_} {_}.
Arguments gcd_deps_ids {_} {_}.
Arguments gcd_cmra_eq {_} {_}.

(* NOTE: [gen_cmra_data] contains a [cmra] and hence we use [option2] as using
 * [option] would give a universe inconsistency. *)
Definition gen_cmras_data Σ := ∀ (i : gid Σ), option2 (gen_cmra_data Σ i).

(* Each entry in [gen_cmras_data] contain a list of cameras that should be the
 * cmras of the dependencies. This duplicated information in the sense that the
 * cmras of the dependencies is also stored at their indices. We say that a
 * [gen_cmras_data] is _well-formed_ if this duplicated information is equal.
 * *)

(* [map] is well-formed at the index [id]. *)
Definition omega_wf_at {Σ} (map : gen_cmras_data Σ) id : Prop :=
  match map id with
  | None2 => True
  | Some2 gcd =>
      ∀ idx, ∃ gcd2,
        let id2 := gcd.(gcd_deps_ids) !!! idx in
        map id2 = Some2 gcd2 ∧
        gcd2.(gcd_cmra) = gcd.(gcd_deps) !!! idx
  end.

(** [map] is well-formed at all indices. *)
Definition omega_wf {Σ} (map : gen_cmras_data Σ) : Prop :=
  ∀ id, omega_wf_at map id.

(** [gGenCmras] contains a partial map from the type of cameras into a "set"
of valid transformation function for that camera. *)
Class gGenCmras (Σ : gFunctors) := {
  gc_map : gen_cmras_data Σ;
  (* Storing this wf-ness criteria for the whole map may be too strong. If this
  * gives problems we can wiggle this requirement around to somewhere else. *)
  gc_map_wf : omega_wf gc_map;
}.

Global Arguments gc_map {_} _.

#[export] Hint Mode gGenCmras +.

(*** Omega helpers *)

(* Various helpers to lookup values in [Ω], hiding the partiality of the map.
 * These are defined using notation as Coq is otherwise not able to figure out
 * when things type-check. *)

(** Lookup the camera in [Ω] at the index [i] *)
Notation Oc Ω i :=
  (match Ω.(gc_map) i with
  | Some2 gcd => gcd.(gcd_cmra)
  | None2 => unit
  end).

(** Lookup the number of depenencies in [Ω] at the index [i] *)
Notation On Ω i :=
  (match Ω.(gc_map) i with
  | Some2 gcd => gcd.(gcd_n)
  | None2 => 0
  end).

(** Lookup the dependency cameras in [Ω] at the index [i] *)
Notation Ocs Ω i :=
  (match Ω.(gc_map) i as o return ivec (
    match o with Some2 gcd12 => gcd12.(gcd_n) | None2 => 0 end
  ) cmra with
  | Some2 gcd => gcd.(gcd_deps)
  | Nil2 => inil
  end).

(* The remaining helpers are not defined using notation as that has not been needed. *)

Section omega_helpers.
  Context {Σ : gFunctors}.
  Implicit Types (Ω : gGenCmras Σ).

  (* (** Lookup the number of depenencies in [Ω] at the index [i] *) *)
  (* Equations Oids Ω i : ivec (On Ω i) (gid Σ) := *)
  (*   | Ω, i with Ω.(gc_map) i => { *)
  (*     | Some2 gcccd => gcccd.(gcd_deps_ids) *)
  (*     | Nil2 => inil *)
  (*   }. *)

  (** Lookup the number of depenencies in [Ω] at the index [i] *)
  Definition Oids Ω i : ivec (On Ω i) (gid Σ) :=
    match Ω.(gc_map) i as o return ivec (
      match o with Some2 gcd12 => gcd12.(gcd_n) | None2 => 0 end
    ) (gid Σ) with
    | Some2 gcd => gcd.(gcd_deps_ids)
    | Nil2 => inil
    end.

  Equations Oeq' Ω i : option2 (generational_cmraR (Oc Ω i) (Ocs Ω i) = R Σ i) :=
  | Ω, i with Ω.(gc_map) i => {
    | Some2 gcccd => Some2 gcccd.(gcd_cmra_eq)
    | None2 => None2
  }.

  (** Lookup the dependency cameras in [Ω] at the index [i] *)
  Definition Oeq Ω i :
      option2 (generational_cmraR (Oc Ω i) (Ocs Ω i) = R Σ i) :=
    (match Ω.(gc_map) i as o return
      (option2
        (generational_cmraR
           match o with
           | Some2 gcd => gcd_cmra gcd
           | None2 => unitR
           end
           match o return
               (ivec match o with
                     | Some2 gcd12 => gcd_n gcd12
                     | None2 => 0
                     end cmra)
           with
           | Some2 gcd => gcd_deps gcd
           | None2 => []
           end = rFunctor_apply (gFunctors_lookup Σ i) (iPropO Σ)))
    with
    | Some2 gcd => Some2 gcd.(gcd_cmra_eq)
    | None2 => None2
    end).

  Lemma generational_cmraR_Oc_Ocs {Ω} {A n} {DS : ivec n cmra}
      id (eq_n : On Ω id = n) :
    Oc Ω id = A →
    Ocs Ω id = rew <- eq_n in DS →
    generational_cmraR A DS = generational_cmraR (Oc Ω id) (Ocs Ω id).
  Proof.
    revert eq_n.
    destruct (Ω.(gc_map) id); simpl.
    - intros <- <- ->. done.
    - intros <- <- ->. done.
  Qed.

  Lemma On_omega_lookup {Ω n} id gti
      (eq1 : Ω.(gc_map) id = Some2 gti) (eq2 : gti.(gcd_n) = n) :
    On Ω id = n.
  Proof. rewrite eq1. rewrite eq2. reflexivity. Qed.

  (** This lemma crucially relies on [Ω] being well-formed. *)
  Lemma Ocs_Oids_distr {Ω : gGenCmras Σ} id (idx : fin (On Ω id)) :
    Ocs Ω id !!! idx = Oc Ω (Oids Ω id !!! idx).
  Proof.
    specialize (gc_map_wf id).
    revert idx.
    rewrite /omega_wf_at /omega_wf_at /Oids.
    destruct (gc_map Ω id) eqn:eq.
    - intros idx wf.
      destruct (wf idx) as (gcd2 & -> & ->).
      reflexivity.
    - intros i. inversion i.
  Qed.

End omega_helpers.

(* We define [genInG] with is our generational replacement for [inG]. *)

Class genInG {n} (Σ : gFunctors) Ω (A : cmra) (DS : ivec n cmra) := GenInG {
  genInG_id : gid Σ;
  genInG_inG_deps : ∀ i d, DS !!! i = d → inG Σ (generational_cmraR A DS);
  genInG_gti : gen_cmra_data Σ genInG_id;
  genInG_gen_trans : Some2 genInG_gti = Ω.(gc_map) genInG_id;
  genInG_gti_typ : A = genInG_gti.(gcd_cmra);
  genInG_gcd_n : genInG_gti.(gcd_n) = n;
  genInG_gcd_deps : DS = eq_rect _ (λ n, ivec n _) genInG_gti.(gcd_deps) _ genInG_gcd_n;
}.

Global Arguments genInG_id {_} {_} {_} {_} {_} _.

Definition gen_cmra_eq {A DA C : cmra} {dn n} {DS : ivec n cmra} {DDS : ivec dn cmra}
  (eq : A = DA)
  (eqN : dn = n)
  (eqDS : DS = eq_rect _ (λ n, ivec n _) DDS _ eqN)
  (eq2 : generational_cmraR DA DDS = C) : generational_cmraR A DS = C.
Proof. rewrite -eq2 -eq. destruct eqN. rewrite eqDS. reflexivity. Defined.

Lemma gen_cmra_eq_refl {DA C : cmra} {dn} {DDS : ivec dn cmra}
    (eq2 : generational_cmraR DA DDS = C) :
  gen_cmra_eq eq_refl eq_refl eq_refl eq2 = eq2.
Proof. destruct eq2. done. Qed.

(* The regular [inG] class can be derived from [genInG]. *)
Global Instance genInG_inG {n : nat} `{i : !genInG Σ Ω A DS} :
    inG Σ (generational_cmraR A DS) := {|
    inG_id := genInG_id (n := n) i;
    inG_prf := gen_cmra_eq genInG_gti_typ genInG_gcd_n
                           genInG_gcd_deps genInG_gti.(gcd_cmra_eq);
  |}.

(* Knowledge that [A] is a resource, with the information about its dependencies
hidden in the dependent pair. *)
Class genInSelfG (Σ : gFunctors) Ω (A : cmra) := GenInG2 {
  genInSelfG_n : nat;
  genInSelfG_DS : ivec genInSelfG_n cmra;
  genInSelfG_gen : genInG Σ Ω A (genInSelfG_DS);
}.

Existing Instance genInSelfG_gen.

Lemma rel_over_eq {n m A1 A2} {DS1 : ivec n cmra} {DS2 : ivec m cmra} (eq : m = n) :
  A1 = A2 →
  DS1 = eq_rect _ (λ n, ivec n _) DS2 _ eq →
  rel_over DS1 A1 = rel_over DS2 A2.
Proof.
  intros ->.
  intros ->.
  destruct eq.
  done.
Defined.

Lemma hvec_eq {n m} (eq : m = n) (DS : ivec n Type) (DS2 : ivec m Type) :
  DS = rew [λ n, ivec n _] eq in DS2 →
  hvec n DS = hvec m DS2.
Proof. destruct eq. intros ->. done. Qed.

Lemma hvec_fmap_eq {n m A} {f : A → Type} (eq : m = n) (DS : ivec n A) (DS2 : ivec m A) :
  DS = rew [λ n, ivec n _] eq in DS2 →
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
  Lemma Oc_genInG_eq :
    Oc Ω (genInG_id i) = A.
  Proof.
    rewrite -genInG_gen_trans.
    apply (eq_sym genInG_gti_typ).
  Defined.

  (** Equality for [On] and [genInG]. *)
  Lemma On_genInG :
    On Ω (genInG_id i) = n.
  Proof.
    apply (
      On_omega_lookup (genInG_id i) (_) (eq_sym genInG_gen_trans) (genInG_gcd_n (genInG := i))).
  Defined.

  Lemma Ocs_inG :
    rew dependent [fun n _ => ivec n cmra] On_genInG in Ocs Ω (genInG_id i) = DS.
  Proof.
    rewrite /On_genInG.
    destruct i.
    simpl.
    rewrite genInG_gcd_deps0.
    destruct (On_omega_lookup genInG_id0 genInG_gti0 _ genInG_gcd_n0).
    destruct genInG_gti0.
    simpl in *.
    clear -genInG_gcd_n0 genInG_gen_trans0.
    destruct (gc_map Ω _).
    2: { congruence. }
    destruct g. simpl in *.
    destruct genInG_gcd_n0.
    simpl.
    inversion genInG_gen_trans0.
    apply inj_right_pair in H1.
    congruence.
  Qed.

  Lemma omega_genInG_cmra_eq   :
    generational_cmraR (gcd_cmra genInG_gti) (gcd_deps genInG_gti) =
      generational_cmraR (Oc Ω (genInG_id i)) (Ocs Ω (genInG_id i)).
  Proof.
    destruct i. simpl.
    destruct (Ω.(gc_map) genInG_id0) eqn:eq; simpl.
    - assert (Some2 genInG_gti0 = Some2 g) as [= <-].
      { congruence. }
      done.
    - assert (Some2 genInG_gti0 = None2) as [=].
      rewrite -eq. done.
  Defined.

  Lemma omega_genInG_cmra_eq2   :
    generational_cmraR A DS =
      generational_cmraR (Oc Ω (genInG_id i)) (Ocs Ω (genInG_id i)).
  Proof.
    rewrite -omega_genInG_cmra_eq.
    destruct i. simpl in *.
    rewrite -genInG_gti_typ0.
    destruct genInG_gcd_n0.
    simpl in *.
    destruct genInG_gcd_deps0.
    done.
  Defined.

  Lemma rel_over_Oc_Ocs_genInG :
    rel_over DS A = rel_over (Ocs Ω (genInG_id _)) (Oc Ω (genInG_id _)).
  Proof.
    destruct genInG_gen_trans.
    apply (rel_over_eq genInG_gcd_n).
    - apply genInG_gti_typ.
    - apply genInG_gcd_deps.
  Defined.

  Lemma trans_for_genInG :
    trans_for n DS = trans_for (On Ω _) (Ocs Ω (genInG_id _)).
  Proof.
    destruct genInG_gen_trans.
    rewrite /trans_for.
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

  Equations build_trans_at (m : iResUR Σ) (i : gid Σ)
      (tts : gmap gname (Oc Ω i → Oc Ω i)) : gmapUR gname (Rpre Σ i) :=
  | m, i, tts, with Ω.(gc_map) i => {
    | Some2 gccd =>
        map_imap (λ γ (a : Rpre Σ i),
          (* If the map of transmap contains a transformation then we apply the
           * transformation otherwise we leave the element unchanged. In all
           * cases we apply something of the form [cmra_map_transport]. *)
          let inner_trans : gccd.(gcd_cmra) → gccd.(gcd_cmra) :=
            default (λ a, a) (tts !! γ) in
          let trans :=
            cmra_map_transport gccd.(gcd_cmra_eq) (gen_cmra_trans inner_trans)
          in Some $ map_unfold $ trans $ map_fold a
        ) (m i)
    | None2 => m i
  }.

  (** This is a key definition for [TransMap]. It builds a global generational
   * transformation based on the transformations in [transmap]. *)
  Definition build_trans transmap : (iResUR Σ → iResUR Σ) :=
    λ (m : iResUR Σ), λ (i : gid Σ), build_trans_at m i (transmap i).

  Lemma core_Some_pcore {A : cmra} (a : A) : core (Some a) = pcore a.
  Proof. done. Qed.

  #[global]
  Lemma build_trans_generation transmap :
    transmap_valid transmap → GenTrans (build_trans transmap).
  Proof.
    intros transmapGT.
    rewrite /build_trans.
    split.
    - rewrite /Proper.
      intros ??? eq i γ.
      specialize (eq i γ).
      rewrite build_trans_at_equation_1.
      rewrite /build_trans_at_clause_1.
  Admitted.
  (*
      destruct (Ω.(gc_map) i). last apply eq.
      rewrite 2!map_lookup_imap.
      destruct (y i !! γ) as [b|] eqn:look1;
        rewrite look1; rewrite look1 in eq; simpl.
      2: { apply dist_None in eq. rewrite eq. done. }
      apply dist_Some_inv_r' in eq as (a & look2 & eq).
      apply symmetry in eq.
      rewrite look2.
      destruct (transmap i !! γ) eqn:look; simpl.
      2: { solve_proper. }
      apply transmapGT in look as [gt ?].
      solve_proper.
    - intros ?? Hval.
      intros i γ.
      destruct (Oeq Ω i); last apply Hval.
      rewrite !map_lookup_imap.
      specialize (Hval i γ).
      destruct (a i !! γ) eqn:eq; rewrite eq /=; last done.
      rewrite eq in Hval.
      apply Some_validN.
      apply: cmra_morphism_validN.
      (* rewrite /cmra_map_transport. *)
      destruct (transmap i !! γ) as [pick|] eqn:eq2.
      * simpl.
        specialize (transmapGT i γ pick eq2) as GT.
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
      destruct (Oeq Ω i). 2: { rewrite lookup_core. reflexivity. }
      rewrite 2!map_lookup_imap.
      rewrite lookup_core.
      destruct (m i !! γ) as [a|] eqn:look; rewrite look; simpl; last done.
      simpl.
      rewrite core_Some_pcore.
      rewrite core_Some_pcore.
      destruct (transmap i !! γ) as [pick|] eqn:pickLook; simpl.
      * rewrite -cmra_morphism_pcore.
        specialize (transmapGT i γ pick pickLook) as ?.
        admit.
        (* rewrite -generation_pcore. *)
        (* rewrite -(cmra_morphism_pcore map_fold). *)
        (* (* rewrite -cmra_morphism_pcore. *) *)
        (* destruct (pcore a); try done. *)
      * (* destruct (pcore a); try done. *)
        admit.
    - intros m1 m2.
      intros i γ.
      rewrite 2!discrete_fun_lookup_op.
      destruct (Oeq Ω i); last reflexivity.
      rewrite !map_lookup_imap.
      rewrite 2!lookup_op.
      rewrite !map_lookup_imap.
      destruct (m1 i !! γ) eqn:eq1; destruct (m2 i !! γ) eqn:eq2;
        rewrite eq1 eq2; simpl; try done.
      rewrite -Some_op.
      f_equiv.
      rewrite map_unfold_op.
      f_equiv.
      destruct (transmap i !! γ) as [pick|] eqn:pickLook.
      * specialize (transmapGT i γ pick pickLook) as ?.
        rewrite -cmra_map_transport_op.
        f_equiv.
        rewrite -cmra_morphism_op.
        done.
      * simpl.
        rewrite -cmra_map_transport_op.
        f_equiv.
        rewrite -cmra_morphism_op.
        done.
  Admitted.
   *)

  Lemma build_trans_at_singleton_neq id1 id2 mm pick :
    id1 ≠ id2 →
    build_trans_at (discrete_fun_singleton id1 mm) id2 pick ≡ ε.
  Proof.
    intros neq.
    rewrite build_trans_at_equation_1.
    rewrite /build_trans_at_clause_1.
    destruct (gc_map Ω id2).
    - rewrite discrete_fun_lookup_singleton_ne; last done.
      rewrite map_imap_empty.
      done.
    - rewrite discrete_fun_lookup_singleton_ne; last done.
      done.
  Qed.

  Lemma build_trans_singleton_alt
      picks id γ
      (a : generational_cmraR (Oc Ω id) (Ocs Ω id)) eqIn (V : transmap_valid picks) pps :
    picks id = pps →
    build_trans picks (discrete_fun_singleton id {[ γ := (map_unfold (cmra_transport eqIn a))
      ]}) ≡
    (discrete_fun_singleton id {[
      γ := map_unfold (cmra_transport eqIn (gen_cmra_trans
            (default (λ a, a) (picks id !! γ)) a))
    ]}).
  Proof.
  Admitted.

  Lemma build_trans_singleton {A n} (DS : ivec n cmra) {i : genInG Σ Ω A DS}
        (γ : gname) picks a pps (V : transmap_valid picks) :
    picks (genInG_id i) = pps →
    build_trans picks (own.iRes_singleton γ (a : generational_cmraR A DS)) ≡
      own.iRes_singleton γ (
        gen_cmra_trans (cmra_map_transport Oc_genInG_eq (default (λ a, a) (pps !! γ) )) a
      ).
  Proof.
    rewrite /build_trans. simpl.
    intros picksLook id.
    rewrite /own.iRes_singleton.
    destruct (decide (id = genInG_id i)) as [eq|neq].
    - intros γ2.
      rewrite build_trans_at_equation_1.
      rewrite eq.
      rewrite picksLook.
      rewrite /build_trans_at_clause_1.
      assert (∃ bingo, pps !! γ = bingo ∧ (bingo = None ∨ (∃ t, bingo = Some t ∧ GenTrans t)))
          as (mt & ppsLook & disj).
      { exists (pps !! γ).
        split; first done.
        destruct (pps !! γ) eqn:ppsLook. 2: { left. done. }
        right. eexists _. split; try done.
        eapply V. rewrite picksLook. done. }
      clear V picksLook picks.
      rewrite /Oc_genInG_eq.
      (* NOTE: This destruct only works when the circumstances are exactly right. *)
      destruct genInG_gen_trans.
      (* destruct (Ω.(gc_map) (genInG_id i)) eqn:omegaLook. *)
      (* 2: { rewrite genInG_gen_trans in omegaLook. congruence. } *)
      rewrite map_lookup_imap.
      rewrite 2!discrete_fun_lookup_singleton.
      destruct (decide (γ = γ2)) as [<- | neqγ].
      2: { rewrite !lookup_singleton_ne; done. }
      rewrite 2!lookup_singleton.
      simpl.
      f_equiv.
      f_equiv.
      rewrite ppsLook. simpl.
      rewrite /own.inG_unfold.
      destruct disj as [-> | (t & -> & GT)].
      + rewrite map_fold_unfold.
        destruct i. simpl in *.
        simpl.
        rewrite /genInG_inG. simpl.
        clear.
        destruct genInG_gti0. simpl in *.
        clear.
        simpl.
        destruct genInG_gcd_n0. simpl.
        destruct genInG_gti_typ0. simpl.
        simpl in genInG_gcd_deps0.
        destruct genInG_gcd_deps0.
        rewrite gen_cmra_eq_refl.
        rewrite cmra_map_transport_cmra_transport.
        f_equiv.
      + rewrite map_fold_unfold.
        destruct i. simpl in *.
        simpl.
        rewrite /genInG_inG. simpl.
        clear.
        destruct genInG_gti0. simpl in *.
        clear.
        simpl.
        destruct genInG_gcd_n0. simpl.
        destruct genInG_gti_typ0. simpl.
        simpl in genInG_gcd_deps0.
        destruct genInG_gcd_deps0.
        rewrite gen_cmra_eq_refl.
        rewrite cmra_map_transport_cmra_transport.
        f_equiv.
    - simpl.
      rewrite discrete_fun_lookup_singleton_ne; last done.
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
Record promise_info_at {Σ} (Ω : gGenCmras Σ) id := {
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
  pi_id : gid Σ; (* The index of the RA in the global RA *)
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
    (cs : hvec (On Ω id) (f <$> Ocs Ω id)) i : f (Oc Ω (Oids Ω id !!! i)) :=
  eq_rect _ _ (hvec_lookup_fmap cs i) _ (Ocs_Oids_distr _ _).

(** Information about a promise _except_ for any information concerning its
 * dependencies. This lets us talk about a promise without having to talk about
 * it's depencencies (and their dependencies, and their dependencies, and so on
 * recursively). This also represents exactly the information that is stored
 * about each dependency in [promise_info]. *)
Record promise_self_info {Σ} Ω := MkPromiseSelfInfo {
  psi_id : gid Σ; (* The index of the RA in the global RA. *)
  psi_γ : gname; (* Ghost name for the promise. *)
  psi_pred : pred_over (Oc Ω psi_id);
}.

Arguments psi_id {_ _}.
Arguments psi_γ {_ _}.
Arguments psi_pred {_ _}.

Definition pi_get_dep `{Ω : gGenCmras Σ}
    (pi : promise_info Ω) idx : promise_self_info Ω :=
  let id := Oids Ω pi.(pi_id) !!! idx in
  let γ := pi.(pi_deps_γs) !!! idx in
  let pred : pred_over (Oc Ω id) := lookup_fmap_Ocs pi.(pi_deps_preds) idx in
  MkPromiseSelfInfo  _ _ id γ pred.

Section promise_info.
  Context `{Ω : gGenCmras Σ}.

  Implicit Types (prs : list (promise_info Ω)).
  Implicit Types (promises : list (promise_info Ω)).
  Implicit Types (pi : promise_info Ω).

  (** Convert a [promise_info] into a [promise_self_info] by discarding fields
   * about dependencies. *)
  Definition promise_info_to_self pi :=
    {| psi_id := pi_id pi; psi_γ := pi_γ pi; psi_pred := pi_pred pi |}.

  Definition promises_different p1 p2 :=
    p1.(pi_id) ≠ p2.(pi_id) ∨ p1.(pi_γ) ≠ p2.(pi_γ).

  Definition promises_self_different p1 p2 :=
    p1.(psi_id) ≠ p2.(psi_id) ∨ p1.(psi_γ) ≠ p2.(psi_γ).

  Definition res_trans_transport {id1 id2}
      (eq : id1 = id2) (t : R Σ id1 → R Σ id1) : (R Σ id2 → R Σ id2) :=
    eq_rect _ (λ id, _) t _ eq.

  Definition res_pred_transport {id1 id2} (eq : id1 = id2)
      (t : (R Σ id1 → R Σ id1) → Prop) : ((R Σ id2 → R Σ id2) → Prop) :=
    eq_rect _ (λ id, _) t _ eq.

  Definition gcd_transport {id1 id2}
      (eq : id1 = id2) (gcd : gen_cmra_data Σ id1) : gen_cmra_data Σ id2 :=
    eq_rect _ (λ id, _) gcd _ eq.

  (* Definition pred_gcd_transport {p_d ps} *)
  (*     (eq1 : p_d.(psi_id) = ps.(pi_id)) *)
  (*     (eq2 : gcd_transport eq1 (psi_gcd p_d) = pi_gcd ps) *)
  (*     (psi_pred : pred_over (gcd_cmra (psi_gcd p_d))) : *)
  (*     (gcd_cmra (pi_gcd ps) → gcd_cmra (pi_gcd ps)) → Prop. *)
  (* Admitted. *)
  (*   (* match eq1 with *) *)
  (*   (* | eq_refl => eq_rect _ (λ id, pred_over (gcd_cmra id)) psi_pred _ eq2 *) *)
  (*   (* end. *) *)

  (** The promise [p] satisfies the dependency [p_d]. Note that the predicate
   * in [p_d] may not be the same as the one in [p]. When we combine lists of
   * promises some promises might be replaced by stronger ones. Hence we only
   * require that the predicate in [p] is stronger than the one in [p_d]. *)
  Definition promise_satisfy_dep (p_d : promise_self_info Ω) ps :=
    ∃ (eq : p_d.(psi_id) = ps.(pi_id)),
      p_d.(psi_γ) = ps.(pi_γ) ∧
      (* The predicate in [ps] is stronger than what is stated in [p_d] *)
      (* pred_stronger ps.(pi_pred) p_d.(psi_pred). *)
      pred_stronger ps.(pi_pred) (eq_rect _ (λ id, pred_over (Oc Ω id)) p_d.(psi_pred) _ eq).

  (** For every dependency in [p] the list [promises] has a sufficient
   * promise. *)
  Definition promises_has_deps pi promises :=
    ∀ idx, ∃ p2, p2 ∈ promises ∧ promise_satisfy_dep (pi_get_dep pi idx) p2.

  (** The promise [p] is well-formed wrt. the list [promises] of promises that
   * preceeded it. *)
  Definition promise_wf pi promises : Prop :=
    (∀ p2, p2 ∈ promises → promises_different pi p2) ∧
    promises_has_deps pi promises.

  (* This definition has nice computational behavior when applied to a [cons]. *)
  Fixpoint promises_wf promises : Prop :=
    match promises with
    | nil => True
    | cons p promises' => promise_wf p promises' ∧ promises_wf promises'
    end.

  (* NOTE: Not used, but should be implied by [promises_wf] *)
  Definition promises_unique promises : Prop :=
    ∀ (i j : nat) pi1 pi2, i ≠ j →
      (* promises !! i = Some p1 → promises !! j = Some p2 → *)
      pi1.(pi_id) ≠ pi2.(pi_id) ∨ pi1.(pi_γ) ≠ pi2.(pi_γ).

  Lemma promises_has_deps_cons p prs :
    promises_has_deps p prs →
    promises_has_deps p (p :: prs).
  Proof.
    intros hasDeps idx.
    destruct (hasDeps idx) as (p2 & ? & ?).
    eauto using elem_of_list_further.
  Qed.

  (* A well formed promise is not equal to any of its dependencies. *)
  Lemma promise_wf_neq_deps p promises :
    promise_wf p promises →
    ∀ (idx : fin (On Ω p.(pi_id))),
      promises_self_different (promise_info_to_self p) (pi_get_dep p idx).
      (* pi_id p ≠ dd_id (pi_get_dd p idx) ∨ pi_γ p ≠ dd_γ (pi_get_dd p idx). *)
  Proof.
    intros [uniq hasDeps] idx.
    rewrite /promises_self_different.
    destruct (hasDeps idx) as (p2 & elem & idEq & γEq & jhhi).
    rewrite idEq γEq.
    destruct (uniq _ elem) as [?|?]; auto.
  Qed.

  Lemma promises_well_formed_lookup promises (idx : nat) pi :
    promises_wf promises →
    promises !! idx = Some pi →
    promises_has_deps pi promises. (* We forget the different part for now. *)
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

  (* For soundness we need to be able to build a map of gts that agree with
   * picks and that satisfy all promises.

     We need to be able to extend picks along a list of promises.

     We must also be able to combine to lists of promises.
  *)

  Equations promises_lookup_at promises iid (γ : gname) : option (promise_info_at _ iid) :=
  | [], iid, γ => None
  | p :: ps', iid, γ with decide (p.(pi_id) = iid), decide (p.(pi_γ) = γ) => {
    | left eq_refl, left eq_refl => Some p.(pi_at);
    | left eq_refl, right _ => promises_lookup_at ps' p.(pi_id) γ
    | right _, _ => promises_lookup_at ps' iid γ
  }.

  (* NOTE: Not sure if this function is a good idea. *)
  Definition promises_lookup promises id γ : option (promise_info _) :=
    MkPi id γ <$> (promises_lookup_at promises id γ).

  Lemma promises_lookup_at_Some promises id γ pia :
    promises_lookup_at promises id γ = Some pia →
    MkPi id γ pia ∈ promises.
  Proof.
    induction promises as [|[id' γ' ?] ? IH]; first by inversion 1.
    rewrite promises_lookup_at_equation_2.
    rewrite promises_lookup_at_clause_2_equation_1.
    simpl.
    destruct (decide (id' = id)) as [->|neq].
    - destruct (decide (γ' = γ)) as [->|neq].
      * simpl.
        intros [= <-].
        apply elem_of_list_here.
      * rewrite promises_lookup_at_clause_2_clause_1_equation_2.
        intros look.
        apply elem_of_list_further.
        apply IH.
        apply look.
    - rewrite promises_lookup_at_clause_2_clause_1_equation_3.
      intros look.
      apply elem_of_list_further.
      apply IH.
      done.
  Qed.

  Lemma promises_wf_elem_of_head id γ pia1 pia2 promises :
    promises_wf ({| pi_id := id; pi_γ := γ; pi_at := pia2 |} :: promises) →
    {| pi_id := id; pi_γ := γ; pi_at := pia1 |}
      ∈ {| pi_id := id; pi_γ := γ; pi_at := pia2 |} :: promises →
    pia1 = pia2.
  Proof.
    intros [(diff & ?) ?].
    intros [eq|?]%elem_of_cons.
    - inversion eq.
      apply inj_right_pair.
      done.
    - destruct (diff _ H1) as [neq|neq]; simpl in neq; congruence.
  Qed.

  Lemma promises_elem_of promises id γ pia :
    promises_wf promises →
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
        intros ?%promises_wf_elem_of_head; [congruence | assumption].
      * rewrite promises_lookup_at_clause_2_clause_1_equation_2.
        simpl.
        intros [?|?]%elem_of_cons; first congruence.
        apply IH; [apply wf | done].
    - rewrite promises_lookup_at_clause_2_clause_1_equation_3.
      intros [?|?]%elem_of_cons; first congruence.
      apply IH; [apply wf | done].
  Qed.

  (** [pia1] is a better promise than [pia2]. *)
  Definition promise_stronger {id} (pia1 pia2 : promise_info_at _ id) : Prop :=
    pia1.(pi_deps_γs) = pia2.(pi_deps_γs) ∧ (* maybe this req can be handled in a slightly less ad-hoc manner *)
    rel_stronger pia1.(pi_rel) pia2.(pi_rel)
    (* pred_stronger p1.(pi_pred) p2.(pi_pred) ∨ *)
    .

  (** This definition is supposed to encapsulate what ownership over the
   * resources for [prs1] and [prs2] entails. *)
  Definition promises_overlap_pred prs1 prs2 : Prop :=
    ∀ id γ p1 p2,
      promises_lookup_at prs1 id γ = Some p1 →
      promises_lookup_at prs2 id γ = Some p2 →
      promise_stronger p1 p2 ∨ promise_stronger p2 p1.

  (* (* NOTE: We can note merge promises with a definition as we need to rely
      * on evidence that is in [Prop]. *) *)
  (* Fixpoint merge_promises prs1 prs2 := *)
  (*   match prs1 with *)
  (*   | [] => prs2 *)
  (*   | p :: prs1' => *)
  (*     if decide (promises_lookup prs2 p.(pi_id) p.(pi_γ) = None) *)
  (*     then p :: (merge_promises prs1' prs2) *)
  (*     else merge_promises prs1' prs2 *)
  (*   end. *)

  (** For every promise in [prs2] there is a stronger promise in [prs1]. *)
  Definition promise_list_stronger prs1 prs2 : Prop :=
    ∀ id γ pia2,
      promises_lookup_at prs2 id γ = Some pia2 →
      ∃ pia1,
        promises_lookup_at prs1 id γ = Some pia1 ∧
        promise_stronger pia1 pia2.

  (* How to merge promises, intuitively?
   * 1. From the first list add the suffix of promises not in the other.
   * 2. From the second list add the suffix of promises not in the other.
   * 3. The last element in both lists is now also present in the other.
   *    - If they are for the same id+γ then add the strongest.
   *    - If one of them is stronger than the one in the other list then add that one.
   *    - If they are both weaker???
   *)
  Lemma merge_promises prs1 prs2 :
    promises_wf prs1 →
    promises_wf prs2 →
    ∃ prs3,
      promises_wf prs3 ∧
      (∀ pi, pi ∈ prs3 → pi ∈ prs1 ∨ pi ∈ prs2) ∧
      promise_list_stronger prs3 prs1 ∧
      promise_list_stronger prs3 prs2.
  Proof.
  Admitted.

  (* NOTE: Not used.*)
  Lemma promises_lookup_different p p2 prs2 :
    p2 ∈ prs2 →
    promises_lookup prs2 (pi_id p) (pi_γ p) = None →
    promises_different p p2.
  Proof.
  Abort. (* should be true but not used *)

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
  Definition trans_at_deps transmap (i : gid Σ) (γs : ivec (On Ω i) gname)
      (ts : hvec (On Ω i) (cmra_to_trans <$> Ocs Ω i)) :=
    ∀ idx,
      let id := Oids Ω i !!! idx in
      let t : Oc Ω id → Oc Ω id := lookup_fmap_Ocs ts idx in
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

  Lemma promises_has_deps_resp_promises p idx p_d promises transmap :
    pi_get_dep p idx = p_d →
    promises_has_deps p promises →
    transmap_resp_promises transmap promises →
    ∃ t, psi_pred p_d t ∧ transmap (psi_id p_d) !! psi_γ p_d = Some t.
  Proof.
    intros look hasDeps resp.
    rewrite /transmap_resp_promises Forall_forall in resp.
    rewrite -look.
    specialize (hasDeps idx) as (p2 & Helem & eq1 & eq2 & strong).
    destruct (resp _ Helem) as (ts & (t & tmLook & ? & relHolds)).
    specialize (p2.(pi_rel_to_pred) ts t relHolds) as predHolds.
    exists (Oc_trans_transport (eq_sym eq1) t).
    split.
    * apply strong in predHolds.
      clear -predHolds. destruct eq1. simpl. done.
    * rewrite eq2. clear -tmLook. destruct eq1. apply tmLook.
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
    promises_wf (p :: promises) →
    transmap_resp_promises transmap promises →
    ∃ ts,
      trans_at_deps transmap p.(pi_id) p.(pi_deps_γs) ts ∧
      preds_hold p.(pi_deps_preds) ts.
  Proof.
    intros WF resp.
    destruct WF as [[uniq hasDeps] WF'].
    edestruct (fun_ex_to_ex_hvec_fmap (F := cmra_to_trans) (Ocs Ω (pi_id p))
      (λ i t,
        let t' := eq_rect _ _ t _ (Ocs_Oids_distr _ _) in
        let pred := hvec_lookup_fmap p.(pi_deps_preds) i in
        pred t ∧
        transmap (Oids Ω p.(pi_id) !!! i) !! (p.(pi_deps_γs) !!! i) = Some t'))
      as (ts & ?).
    { intros idx.
      specialize (promises_has_deps_resp_promises _ _ (pi_get_dep p idx) _ transmap eq_refl hasDeps resp).
      intros (t & ? & ?).
      exists (eq_rect_r _ t (Ocs_Oids_distr _ _)).
      simpl.
      split.
      * rewrite /pi_get_dep /lookup_fmap_Ocs in H.
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

  Equations transmap_insert_go transmap (id : gid Σ) (γ : gname) (pick : Oc Ω id → Oc Ω id)
    (id' : gid Σ) : gmap gname (Oc Ω id' → Oc Ω id') :=
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

  Lemma transmap_resp_promises_insert p promises transmap t :
    promises_wf (p :: promises) →
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
        promises_well_formed_lookup promises _ p2 WF look) as hasDeps2.
      specialize (hasDeps2 idx) as (p3 & look3 & eq & eq2 & ?).
      simpl in *.
      rewrite eq2.
      destruct p3.
      specialize (uniq _ look3) as [? | ?].
      - rewrite eq. left. done.
      - right. done.
  Qed.

  Lemma transmap_resp_promises_weak transmap prs1 prs2 :
    promises_wf prs2 →
    promise_list_stronger prs1 prs2 →
    transmap_resp_promises transmap prs1 →
    transmap_resp_promises transmap prs2.
  Proof.
    intros wf strong.
    rewrite /transmap_resp_promises.
    rewrite !Forall_forall.
    intros resp [id γ pia2] elm.
    destruct (strong id γ pia2) as (pia1 & look2 & stronger).
    { apply promises_elem_of; done. }
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
    promises_wf promises →
    ∃ (map : TransMap Ω),
      transmap_resp_promises map promises ∧
      transmap ⊆ map.
  Proof.
    induction promises as [|p promises' IH].
    - intros _. exists transmap.
      split; last done.
      apply Forall_nil_2.
    - intros HR [WF WF'].
      specialize (promise_wf_neq_deps _ _ WF) as depsDiff.
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
          -- apply transmap_resp_promises_insert; done.
        * apply transmap_insert_subseteq_r; done.
  Qed.

  Lemma promises_to_maps (promises : list _) :
    promises_wf promises →
    ∃ (transmap : TransMap _), transmap_resp_promises transmap promises.
  Proof.
    intros WF.
    edestruct (transmap_promises_to_maps (λ i : gid Σ, ∅)) as [m [resp a]].
    2: { done. }
    - intros ???. right. done.
    - exists m. apply resp.
  Qed.

End transmap.

(* Arguments promise_info Σ : clear implicits. *)
(* Arguments promise_self_info Σ : clear implicits. *)

Section next_gen_definition.
  Context `{Ω : gGenCmras Σ}.

  Implicit Types (picks : TransMap Ω).

  (* Every generational ghost location consists of a camera and a list of
   * cameras for the dependencies. *)

  (* If a transformation has been picked for one ghost name, then all the
   * dependencies must also have been picked. *)

  (* The resource [m] contains the agreement resources for all the picks in
   * [picks]. We need to know that a picked transformation satisfies the most
   * recent/strongest promise. We thus need the authorative part of the
   * promises. *)
  Definition res_for_picks picks (m : iResUR Σ) :=
    ∀ i,
      dom (picks i) ≡ dom (m i) ∧
      ∀ γ (a : Rpre Σ i),
        m i !! γ = Some a →
        ∃ eq (ts : hvec (On Ω i) (cmra_to_trans <$> Ocs Ω i))
            (γs : ivec (On Ω i) gname) (t : Oc Ω i → Oc Ω i) R Rs,
          Oeq Ω i = Some2 eq ∧
          trans_at_deps picks i γs ts ∧
          huncurry R ts t ∧
          picks i !! γ = Some t ∧
          pred_prefix_list_for Rs R ∧
          a ≡ map_unfold (cmra_transport eq
            (ε, GTS_tok_gen_shot t, ε,
             Some (to_agree (ivec_to_list γs)), gV (●□ (to_max_prefix_list Rs)))).

  Definition own_picks picks : iProp Σ :=
    ∃ m, uPred_ownM m ∗ ⌜ res_for_picks picks m ⌝.

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

  Definition own_promises (ps : list (promise_info Ω)) : iProp Σ :=
    (∀ p, ⌜ p ∈ ps ⌝ -∗
      ∃ eq Rs,
        ⌜ Oeq Ω p.(pi_id) = Some2 eq ⌝ ∧
        ⌜ pred_prefix_list_for Rs p.(pi_rel) ⌝ ∧
        uPred_ownM (discrete_fun_singleton p.(pi_id)
          {[ p.(pi_γ) := map_unfold
            (cmra_transport eq (
              ε, ε, ε,
              Some (to_agree (ivec_to_list p.(pi_deps_γs))),
              gV (◯ (to_max_prefix_list Rs))
            )) ]}
        )).

  #[global]
  Instance own_promise_persistent ps : Persistent (own_promises ps).
  Proof. apply _. Qed.

  Definition nextgen P : iProp Σ :=
    ∃ picks (ps : list (promise_info Ω)),
      (* We own resources for everything in [picks] and [promises]. *)
      own_picks picks ∗ own_promises ps ∗
      ⌜ promises_wf ps ⌝ ∗
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

  Lemma tokens_for_picks_agree_overlap picks1 picks2 m1 m2 :
    res_for_picks picks1 m1 →
    res_for_picks picks2 m2 →
    uPred_ownM m1 -∗
    uPred_ownM m2 -∗
    ⌜ ∀ i, map_agree_overlap (picks1 i) (picks2 i) ⌝.
  Proof.
    iIntros (t1 t2) "m1 m2". iIntros (i).
    iIntros (γ a1 a2 look1 look2).
    specialize (t1 i) as (domEq1 & m1look).
    assert (is_Some (m1 i !! γ)) as [? m1Look].
    { rewrite -elem_of_dom -domEq1 elem_of_dom. done. }
    edestruct m1look as (gti1 & t1 & ? & ? & ? & ? & ? & ? & ? & picks1Look & ? & eq1);
      first done.
    specialize (t2 i) as (domEq2 & m2look).
    assert (is_Some (m2 i !! γ)) as [? m2Look].
    { rewrite -elem_of_dom -domEq2 elem_of_dom. done. }
    edestruct m2look as (gti2 & t2 & ? & ? & ? & ? & ? & ? & ? & picks2Look & ? & eq2);
      first done.
    clear m1look m2look.
    assert (gti1 = gti2) as -> by congruence.
    iCombine "m1 m2" as "m".
    iDestruct (ownM_valid with "m") as "#Hv".
    rewrite discrete_fun_validI.
    setoid_rewrite gmap_validI.
    iSpecialize ("Hv" $! i γ).
    rewrite lookup_op.
    rewrite m1Look m2Look.
    rewrite option_validI /=.
    rewrite eq1 eq2.
    simplify_eq.
    rewrite map_unfold_op.
    clear.
    iClear "m".
    rewrite map_unfold_validI.
    destruct gti2.
    simpl.
    rewrite prod_valid_2st.
    rewrite GTS_tok_gen_shot_agree.
    done.
  Qed.

  Lemma cmra_transport_validI {A B : cmra} (eq : A =@{cmra} B) (a : A) :
    ✓ cmra_transport eq a ⊣⊢@{iPropI Σ} ✓ a.
  Proof. destruct eq. done. Qed.

  Lemma tokens_for_picks_agree_overlap' picks1 picks2 m1 m2 :
    res_for_picks picks1 m1 →
    res_for_picks picks2 m2 →
    uPred_ownM m1 -∗
    uPred_ownM m2 -∗
    ⌜ ∀ i γ a b, (m1 i) !! γ = Some a → (m2 i) !! γ = Some b → a ≡ b ⌝.
  Proof.
    iIntros (t1 t2) "m1 m2". iIntros (i).
    iIntros (γ a1 a2 m1Look m2Look).
    specialize (t1 i) as (domEq1 & m1look).
    edestruct m1look as (gti1 & t1 & ? & ? & ? & ? & ? & ? & ? & picks1Look & ? & eq1);
      first done.
    specialize (t2 i) as (domEq2 & m2look).
    edestruct m2look as (gti2 & t2 & ? & ? & ? & ? & ? & ? & ? & picks2Look & ? & eq2);
      first done.
    clear m1look m2look.
    assert (gti1 = gti2) as -> by congruence.
    iCombine "m1 m2" as "m".
    iDestruct (ownM_valid with "m") as "#Hv".
    rewrite discrete_fun_validI.
    setoid_rewrite gmap_validI.
    iSpecialize ("Hv" $! i γ).
    rewrite lookup_op.
    rewrite m1Look m2Look.
    rewrite option_validI /=.
    rewrite eq1 eq2.
    simplify_eq.
    rewrite map_unfold_op.
    rewrite map_unfold_validI.
    rewrite -cmra_transport_op.
    rewrite cmra_transport_validI.
    rewrite -pair_op.
    rewrite -pair_op.
    rewrite prod_validI.
    rewrite prod_validI.
    rewrite prod_validI.
    rewrite prod_validI.
    iDestruct "Hv" as "((((_ & Hv1) & _) & Hv2) & %Hv3)".
    simpl in Hv3.
    simpl.
    rewrite GTS_tok_gen_shot_agree.
    rewrite -Some_op option_validI to_agree_op_validI.
    iDestruct "Hv1" as %->.
    rewrite gen_pv_op gen_pv_valid in Hv3.
    rewrite auth_auth_dfrac_op_valid in Hv3.
    destruct Hv3 as (? & eq & ?).
    rewrite /map_unfold.
    iDestruct "Hv2" as %hqq.
    apply leibniz_equiv in hqq.
    iPureIntro. f_equiv. f_equiv.
    rewrite hqq.
    rewrite /gV. rewrite /mk_gen_pv.
    split; try done; simpl.
    split; try done; simpl.
    rewrite eq.
    done.
  Qed.

  Lemma m_contains_tokens_for_picks_merge picks1 picks2 (m1 m2 : iResUR Σ) :
    (∀ i, map_agree_overlap (picks1 i) (picks2 i)) →
    (∀ i γ a b, (m1 i) !! γ = Some a → (m2 i) !! γ = Some b → a ≡ b) →
    res_for_picks picks1 m1 →
    res_for_picks picks2 m2 →
    res_for_picks (picks1 ∪ picks2) (m1 ⋅ m2).
  Proof.
    intros overlap1 overlap2 tok1 tok2.
    intros i.
    rewrite /union /transmap_union.
    rewrite dom_op.
    specialize (tok1 i) as (domEq1 & tok1).
    specialize (tok2 i) as (domEq2 & tok2).
    split.
    { rewrite -domEq1 -domEq2. rewrite dom_union. done. }
    intros γ a.
    rewrite discrete_fun_lookup_op.
    rewrite lookup_op.
    case (m1 i !! γ) eqn:look1; rewrite look1;
      case (m2 i !! γ) eqn:look2; rewrite look2.
    - specialize (overlap2 i _ _ _ look1 look2) as elemEq.
      (* Both [picks1] and [picks2] has a pick. *)
      apply tok1 in look1 as (n1 & c1 & t1 & r & rs & R1 & Rlist1 & ? & R1holds & picksLook1 & prf1 & a1).
      apply tok2 in look2 as (n2 & c2 & t2 & ? & ? & R2 & Rlist2 & ? & R2holds & picksLook2 & prf2 & a2).
      intros [= opEq].
      eexists n1, c1, t1, r, rs, R1.
      split; first done.
      split. { apply trans_at_deps_union_l. done. }
      split; first done.
      split. { erewrite lookup_union_Some_l; done. }
      split; first done.
      rewrite -opEq.
      rewrite -elemEq.
      rewrite a1.
      rewrite map_unfold_op.
      f_equiv.
      rewrite -cmra_transport_op.
      f_equiv.
      rewrite -4!pair_op.
      rewrite GTS_tok_gen_shot_idemp.
      rewrite -Some_op.
      rewrite agree_idemp.
      rewrite gen_pv_op.
      rewrite /gV.
      simpl.
      rewrite -auth_auth_dfrac_op.
      done.
    - intros [= ->].
      apply tok1 in look1 as (n & c & t & r & rs & R & Rlist & ? & Rholds & picksLook & rest).
      eexists n, c, t, r, rs, R.
      split; first done.
      split. { apply trans_at_deps_union_l; done. }
      split; first done.
      split. { erewrite lookup_union_Some_l; try done. }
      apply rest.
    - intros [= ->].
      apply tok2 in look2 as (n & c & t & r & rs & R & Rlist & ? & Rholds & picksLook & rest).
      eexists n, c, t, r, rs, R.
      split; first done.
      split. { apply trans_at_deps_union_r; done. }
      split; first done.
      split.
      { erewrite lookup_union_r; try done.
        apply not_elem_of_dom.
        rewrite domEq1.
        rewrite not_elem_of_dom.
        done. }
      apply rest.
    - intros [=].
  Qed.

  Lemma own_picks_sep picks1 picks2 :
    own_picks picks1 -∗
    own_picks picks2 -∗
    own_picks (picks1 ∪ picks2) ∗ ⌜ picks2 ⊆ picks1 ∪ picks2 ⌝.
  Proof.
    iDestruct 1 as (m1) "[O1 %R1]".
    iDestruct 1 as (m2) "[O2 %R2]".
    iDestruct (tokens_for_picks_agree_overlap with "O1 O2") as %disj;
      [done|done|].
    iSplit; last first. { iPureIntro. apply transmap_union_subseteq_r. done. }
    iExists (m1 ⋅ m2).
    iDestruct (tokens_for_picks_agree_overlap' with "O1 O2") as %HI.
    { done. } { done. }
    iCombine "O1 O2" as "$".
    iPureIntro.
    apply m_contains_tokens_for_picks_merge; try done.
  Qed.

End own_picks_properties.

Section own_promises_properties.
  Context `{Ω : gGenCmras Σ}.

  Implicit Types (prs : list (promise_info Ω)).

  (* If two promise lists has an overlap then one of the overlapping promises
   * is strictly stronger than the other. *)
  Lemma own_promises_overlap prs1 prs2 :
    own_promises prs1 -∗
    own_promises prs2 -∗
    ⌜ promises_overlap_pred prs1 prs2 ⌝.
  Proof.
    iIntros "O1 O2".
    iIntros (id γ p1 p2 look1 look2).
    apply promises_lookup_at_Some in look1 as elem1.
    apply promises_lookup_at_Some in look2 as elem2.
    iSpecialize ("O1" $! _ elem1).
    iSpecialize ("O2" $! _ elem2).
    simpl.
    iDestruct "O1" as (eq ???) "O1".
    iDestruct "O2" as (eq' ???) "O2".
    assert (eq' = eq) as -> by congruence.
    iCombine "O1 O2" as "O3".
    rewrite discrete_fun_singleton_op.
    rewrite singleton_op.
    iDestruct (ownM_valid with "O3") as "#Hv".
    iClear "O3".
    rewrite discrete_fun_validI.
    setoid_rewrite gmap_validI.
    iSpecialize ("Hv" $! id γ).
    simpl.
    rewrite discrete_fun_lookup_singleton.
    rewrite lookup_singleton.
    rewrite option_validI.
    rewrite map_unfold_op.
    rewrite map_unfold_validI.
    rewrite -cmra_transport_op.
    rewrite cmra_transport_validI.
    rewrite -2!pair_op.
    rewrite prod_validI /=.
    rewrite prod_validI /=.
    iDestruct "Hv" as "[[_ %Hv2] %Hv]". iPureIntro.
    rewrite -Some_op Some_valid to_agree_op_valid_L in Hv2.
    apply ivec_to_list_inj in Hv2.
    rewrite gen_pv_op gen_pv_valid in Hv.
    rewrite auth_frag_op_valid in Hv.
    apply to_max_prefix_list_op_valid_L in Hv as [Hv|Hv].
    - right.
      split; first done.
      eapply pred_prefix_list_for_prefix_of; done.
    - left.
      split; first done.
      eapply pred_prefix_list_for_prefix_of; done.
  Qed.

End own_promises_properties.

(* In this section we prove structural rules of the nextgen modality. *)

Section nextgen_properties.
  Context {Σ : gFunctors} {Ω : gGenCmras Σ}.
  Implicit Types (P : iProp Σ) (Q : iProp Σ).

  Lemma res_for_picks_empty :
    res_for_picks (λ i : gid Σ, ∅) ε.
  Proof. done. Qed.

  Lemma own_picks_empty :
    ⊢@{iProp Σ} own_picks (λ i : gid Σ, ∅).
  Proof. iExists ε. rewrite ownM_unit' left_id. iPureIntro. done. Qed.

  Lemma own_promises_empty :
    ⊢@{iProp Σ} own_promises [].
  Proof.
    rewrite /own_promises.
    iIntros (? elm).
    inversion elm.
  Qed.

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

  Lemma nextgen_sep_2 P Q :
    (⚡==> P) ∗ (⚡==> Q) ⊢ ⚡==> (P ∗ Q) .
  Proof.
    rewrite /nextgen.
    iIntros "[P Q]".
    iDestruct "P" as (? prs1) "(picks1 & pr1 & %wf1 & HP)".
    iDestruct "Q" as (? prs2) "(picks2 & pr2 & %wf2 & HQ)".
    destruct (merge_promises prs1 prs2) as (prs3 & ? & ? & ? & ?);
      [done|done|].
    (* Combine the picks. *)
    iExists _, prs3.
    iDestruct (own_picks_sep with "picks1 picks2") as "[$ %sub]".
    iSplitL "pr1 pr2".
    { (* (* Maybe the following could be a lemma. *) *)
      iIntros (pi elm).
      edestruct (H0) as [elm2|elm2]; first apply elm.
      - iDestruct ("pr1" $! _ elm2) as (??) "?".
        iExists _, _. iFrame.
      - iDestruct ("pr2" $! _ elm2) as (??) "?".
        iExists _, _. iFrame. }
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
  Context {n} {A} {DS : ivec n cmra} `{!genInG Σ Ω A DS}.
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

  Definition gen_promise_list γ l :=
    own γ (gc_tup_promise_list l).

  Definition gen_token_used γ : iProp Σ :=
    gen_pick_out γ GTS_tok_perm.

  Definition gen_picked_out γ t : iProp Σ :=
    gen_pick_out γ (GTS_tok_gen_shot t).

  Definition gen_token γ : iProp Σ :=
    gen_pick_out γ (GTS_tok_both).

  Definition own_frozen_auth_promise_list γ all : iProp Σ :=
    gen_promise_list γ (
      gP (● to_max_prefix_list all) ⋅ gV (●□ to_max_prefix_list all)
    ).

  Definition own_auth_promise_list γ all : iProp Σ :=
    gen_promise_list γ (gPV (● to_max_prefix_list all)).

  (** Ownership over the token and the promises for [γ]. *)
  Definition token (γ : gname) (γs : ivec n gname) R P : iProp Σ :=
    ∃ (all : list (rel_over DS A)),
      "%pred_prefix" ∷ ⌜ pred_prefix_list_for' all R P ⌝ ∗
      "#deps" ∷ know_deps γ γs ∗
      "token" ∷ gen_token γ ∗
      "auth_preds" ∷ own_auth_promise_list γ all.

  Definition used_token (γ : gname) (γs : ivec n gname) R P : iProp Σ :=
    ∃ (all : list (rel_over DS A)),
      ⌜ pred_prefix_list_for' all R P ⌝ ∗
      know_deps γ γs ∗
      own_frozen_auth_promise_list γ all ∗
      gen_token γ.

  (* TODO: We need some way of converting between the relations stored in
   * [promise_info] and the relations stored by the user.
   *
   * [promise_info] stores everything in relation to Σ. User predicates mention
   * cameras directly and then have evidence (equalities) that the camera is in
   * Σ. To convert a predicate by the user into one in [promise_info] we need
   * to use all of this evidence. That is, we need to translate along all of
   * the equalities. This is a bit like in [own] where users write an element
   * of their camera and then this element is transported along the equality
   * into an element of [Σ i]. *)

  (* (** Knowledge that γ is accociated with the predicates R and P. *) *)
  (* Definition rely (γ : gname) (γs : ivec n gname) R P : iProp Σ := *)
  (*   ∃ (p : promise_info Σ) (all : list (rel_over DS A)), *)
  (*     ⌜ p.(pi_γ) = γ ⌝ ∗ *)
  (*     ⌜ p.(pi_rel) = R ⌝ ∗ *)
  (*     ⌜ p.(pi_pred) = P ⌝ ∗ *)
  (*     ⌜ deps_to_gnames (p.(pi_deps)) γs ⌝ *)
  (*     ⌜ pred_prefix_list_for' all R P ⌝ ∗ *)
  (*     own γ ((None, (None, None), None, *)
  (*             gPV (◯ to_max_prefix_list all)) : generational_cmraR A DS). *)

  (** Knowledge that γ is accociated with the predicates R and P. *)
  Definition rely (γ : gname) (γs : ivec n gname) R P : iProp Σ :=
    ∃ (all : list (rel_over DS A)) promises pia,
      "%γs_eq" ∷ ⌜ pia.(pi_deps_γs) = rew <- [λ n, ivec n _] On_genInG in γs ⌝ ∗
      "%pred_eq" ∷ ⌜ pia.(pi_pred) = rew <- [pred_over] Oc_genInG_eq in P ⌝ ∗
      "%rel_eq" ∷ ⌜ pia.(pi_rel) = rew [id] rel_over_Oc_Ocs_genInG in R ⌝ ∗
      "%rely_pred_prefix" ∷ ⌜ pred_prefix_list_for' all R P ⌝ ∗
      "%pia_in" ∷ ⌜ promises_lookup_at promises _ γ = Some pia ⌝ ∗
      "%prs_wf" ∷ ⌜ promises_wf promises ⌝ ∗
      "#rely_deps" ∷ know_deps γ γs ∗
      "#prs" ∷ own_promises promises ∗
      "#frag_preds" ∷ gen_promise_list γ ((gPV (◯ to_max_prefix_list all))).

End generational_resources.

Definition rely_self `{i : !genInSelfG Σ Ω A}
    γ (P : (A → A) → Prop) : iProp Σ :=
  ∃ γs R, rely (DS := genInSelfG_DS) γ γs R P.

Section rules.
  Context {n : nat} {DS : ivec n cmra} `{!genInG Σ Ω A DS}.

  Lemma own_gen_alloc (a : A) γs :
    ✓ a → ⊢ |==> ∃ γ, gen_own γ a ∗ token γ γs True_rel (λ _, True%type).
  Proof.
    iIntros (Hv).
    rewrite /gen_own.
    rewrite /token.
    iMod (own_alloc
      (gc_tup_deps A DS (ivec_to_list γs) ⋅
       gc_tup_elem DS a ⋅
       gc_tup_pick_out DS GTS_tok_both ⋅
       gc_tup_promise_list (gPV (● to_max_prefix_list (True_rel :: [])))
       )) as (γ) "[[[?A] A'] B]".
    { split; simpl; try done.
      rewrite ucmra_unit_left_id.
      apply gen_pv_valid.
      apply auth_auth_valid.
      apply to_max_prefix_list_valid. }
    iExists γ.
    iModIntro. iFrame.
    iExists _. iFrame.
    iPureIntro.
    apply pred_prefix_list_for'_True.
  Qed.

  Lemma gen_token_split γ :
    gen_token γ ⊣⊢
    own γ (None, GTS_tok_perm, None, None, ε) ∗
    own γ (None, GTS_tok_gen, None, None, ε).
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
  Lemma token_strengthen_promise `{∀ (i : fin n), genInSelfG Σ Ω (DS !!! i)}
      γ γs (deps_preds : preds_for n DS)
      (R_1 R_2 : rel_over DS A) (P_1 P_2 : (A → A) → Prop) :
    (* The new relation is stronger. *)
    (∀ (ts : trans_for n DS) (t : A → A),
       huncurry R_1 ts t → huncurry R_2 ts t ∧ P_2 t) →
    (* The new predicate is stronger. *)
    (∀ t, P_1 t → P_2 t) →
    (* The new relation implies the predicate. *)
    (∀ ts t, huncurry R_2 ts t → P_2 t) →
    (* Evidence that the promise is realizeable. *)
    (∀ (ts : trans_for n DS),
      preds_hold deps_preds ts → ∃ (e : A → A), (huncurry R_2) ts e) →
    (* For every dependency we own a [rely_self]. *)
    (∀ (i : fin n), rely_self (γs !!! i) (hvec_lookup_fmap deps_preds i)) -∗
    token γ γs R_1 P_1 -∗ (* Old token. *)
    token γ γs R_2 P_2. (* Updated token. *)
  Proof.
  Admitted.

  Lemma token_pick γ γs (R : rel_over DS A) P (ts : trans_for n DS) t
      `{∀ (i : fin n), genInSelfG Σ Ω (DS !!! i)} :
    huncurry R ts t →
    (∀ i, gen_picked_out (γs !!! i) (hvec_lookup_fmap ts i)) -∗
    token γ γs R P -∗ |==>
    used_token γ γs R P ∗ gen_picked_out γ t.
  Proof.
  Admitted.

  Lemma token_to_rely γ γs (R : rel_over DS A) P :
    token γ γs R P ⊢ rely γ γs R P.
  Proof.
  Admitted.

  Lemma token_rely_combine_pred γ γs R1 P1 R2 P2 :
    token γ γs R1 P1 -∗ rely γ γs R2 P2 -∗ ⌜ rel_stronger R1 R2 ⌝.
  Proof.
    iNamed 1.
    iNamed 1.
    iDestruct (own_valid_2 with "auth_preds frag_preds") as "val".
    iDestruct (prod_valid_5th with "val") as "%val".
    iPureIntro.
    move: val.
    rewrite gen_pv_op. rewrite gen_pv_valid.
    rewrite auth_both_valid_discrete.
    rewrite to_max_prefix_list_included_L.
    intros [prefix _].
    destruct pred_prefix as [? ?].
    destruct rely_pred_prefix as [? ?].
    eapply pred_prefix_list_for_prefix_of; done.
  Qed.

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

  Lemma rely_combine γ γs1 γs2 R1 P1 R2 P2 :
    rely γ γs1 R1 P1 -∗
    rely γ γs2 R2 P2 -∗
    ⌜ γs1 = γs2 ⌝ ∗
    ⌜ rel_stronger R1 R2 ∨ rel_stronger R2 R1 ⌝.
  Proof.
    iNamed 1.
    iDestruct 1 as (prs2 pia2 ? ? ? ? prefix2 ?) "(? & deps2 & ? & preds2)".
    iDestruct (know_deps_agree with "rely_deps deps2") as %<-.
    iDestruct (own_valid_2 with "frag_preds preds2") as "val".
    iDestruct (prod_valid_5th with "val") as "%val".
    iPureIntro.
    split; first done.
    move: val.
    rewrite gen_pv_op. rewrite gen_pv_valid.
    rewrite auth_frag_valid.
    rewrite to_max_prefix_list_op_valid_L.
    destruct rely_pred_prefix as [(isLast1 & look1) ?].
    destruct prefix2 as [(isLast2 & look2) ?].
    rewrite last_lookup in isLast1.
    rewrite last_lookup in isLast2.
    intros [prefix | prefix].
    - right.
      eapply look2; last done.
      { apply le_pred. apply prefix_length. eassumption. }
      eapply prefix_lookup; done.
    - left.
      eapply look1; last done.
      { apply le_pred. apply prefix_length. eassumption. }
      eapply prefix_lookup; done.
  Qed.

End rules.

Lemma discrete_fun_singleton_included {Σ} {i : gid Σ} {A : cmra} eq (γ : gname)
  (a b : A) :
  a ≼ b →
  ((discrete_fun_singleton i {[γ := map_unfold (cmra_transport eq a)]} : iResUR Σ)
    ≼ discrete_fun_singleton i {[γ := map_unfold (cmra_transport eq b)]}).
Proof.
  intros incl.
  apply discrete_fun_included_spec => id.
  simpl.
  destruct (decide (id = i)) as [->|idNeq].
  2: { by rewrite !discrete_fun_lookup_singleton_ne. }
  rewrite !discrete_fun_lookup_singleton.
  apply singleton_mono.
  apply: cmra_morphism_monotone.
  destruct eq.
  apply incl.
Qed.

Lemma iRes_singleton_included `{i : inG Σ A} (a b : A) γ :
  a ≼ b →
  (own.iRes_singleton γ a) ≼ (own.iRes_singleton γ b).
Proof. apply discrete_fun_singleton_included. Qed.

Section nextgen_assertion_rules.
  (* Rules about the nextgen modality. *)
  Context {n : nat} {DS : ivec n cmra} `{!genInG Σ Ω A DS}.

  Lemma own_build_trans_next_gen γ (m : generational_cmraR A DS) picks
      `{!GenTrans (build_trans picks)} :
    transmap_valid picks →
    own γ m ⊢ ⚡={build_trans picks}=> own γ (
      gen_cmra_trans (cmra_map_transport Oc_genInG_eq (default (λ a, a) (picks _ !! γ))) m
    ).
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
    iStopProof.
    f_equiv.
  Qed.

  Lemma own_promises_nextgen picks ps `{!GenTrans (build_trans picks)} :
    transmap_valid picks →
    own_promises ps ⊢ ⚡={build_trans picks}=> own_promises ps.
  Proof.
    iIntros (val) "#prs".
    rewrite /own_promises.
    iModIntro.
    iIntros (pi elm).
    iDestruct ("prs" $! pi elm) as (??) "-#H". iClear "prs".
    iExists _, _.
    iDestruct "H" as "($ & $ & own)".
    rewrite build_trans_singleton_alt; [ |done|done].
    iStopProof.
    f_equiv.
    simpl.
    apply discrete_fun_singleton_included.
    rewrite gen_cmra_trans_apply. simpl.
    rewrite 4!pair_included.
    split_and!; try done. apply ucmra_unit_least.
  Qed.

  Lemma own_build_trans_next_gen_picked_in γ (m : generational_cmraR A DS) picks
      `{!GenTrans (build_trans picks)} :
    transmap_valid picks →
    own γ m ⊢ ⚡={build_trans picks}=>
      gen_picked_in γ (cmra_map_transport Oc_genInG_eq (default (λ a, a) (picks _ !! γ))
    ).
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
    iDestruct 1 as (? (HPL & ?)) "[deps own]".
    destruct HPL as (? & ?).

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

  Lemma own_gen_cmra_split_picked_in γ a b c d e :
    own γ (a, b, c, d, e) ⊣⊢ own γ (a, ε, ε, ε, ε) ∗ own γ (ε, b, c, d, e).
   Proof.
     rewrite -own_op.
     f_equiv.
     rewrite -!pair_op.
     rewrite !(right_id ε (⋅)).
     repeat split; simpl; try done;
       rewrite !(left_id ε (⋅)); done.
  Qed.

  (* TODO: Prove this lemma. *)
  Lemma rely_nextgen γ γs (R : rel_over DS A) (P : pred_over A)
      `{∀ (i : fin n), genInSelfG Σ Ω (DS !!! i)} :
    rely γ γs R P
    ⊢ ⚡==>
      rely γ γs R P ∗
      ∃ (t : A → A) (ts : trans_for n DS),
        ⌜ huncurry R ts t ∧ (* The transformations satisfy the promise *)
          P t ⌝ ∗ (* For convenience we also give this directly *)
        gen_picked_in γ t ∗
        (* The transformations for the dependencies are the "right" ones *)
        (∀ i, gen_picked_in (γs !!! i) (hvec_lookup_fmap ts i)).
  Proof.
    rewrite /rely.
    iNamed 1.
    rewrite /nextgen.
    iExists (λ i, ∅), promises.
    iSplitL ""; first iApply own_picks_empty.
    iFrame "prs".
    iSplit; first done.
    iIntros (full_picks val resp _).
    iDestruct (own_build_trans_next_gen with "rely_deps") as "rely_deps'"; first done.
    iDestruct (own_build_trans_next_gen with "frag_preds") as "frag_preds'"; first done.
    iDestruct (own_promises_nextgen with "prs") as "prs'"; first done.
    iModIntro.
    edestruct (transmap_resp_promises_lookup_at)
      as (ts & t & look & ? & relHolds); [done|done| ].
    simpl in *.
    rewrite look.
    iDestruct (own_gen_cmra_split_picked_in with "rely_deps'") as "[picked_in $]".
    iSplitL "".
    - iExists all, promises, pia.
      do 6 (iSplit; first done).
      iFrame "prs'".
      clear.
      simpl.
      rewrite /gen_cmra_trans.
      rewrite /gc_tup_promise_list.
      simpl.
      iDestruct (own_gen_cmra_split_picked_in with "frag_preds'") as "[_ $]".
    - iExists (rew [cmra_to_trans] Oc_genInG_eq in t).
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
        rewrite /Oc_genInG_eq in predHolds.
        rewrite /trans_for_genInG.
        rewrite /Oc_genInG_eq.
        rewrite /hvec_fmap_eq.
        destruct genInG0. simpl in *.
        destruct genInG_gen_trans0. simpl.
        destruct genInG_gcd_n0. simpl in *.
        destruct genInG_gti_typ0. simpl in *.
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
  apply forall_fin_2.
  split.
  - apply (GenInG2 _ _ _ n DS1 _).
  - apply (GenInG2 _ _ _ m DS2 _).
Qed.

Section test.
  Context `{max_i : !inG Σ max_natR}.
  Context `{i : !genInG Σ Ω max_natR [max_natR; max_natR] }.

  Definition a_rely :=
    rely (1%positive) [2%positive; 3%positive] (λ Ta Tb Ts, Ta = Ts ∧ Tb = Ts) (λ _, True).

  Section test.
    Variables (A : cmra) (B : cmra) (T1 : A → A) (T2 : B → B)
      (P1 : (A → A) → Prop) (P2 : (B → B) → Prop).

    Definition TS : trans_for _ [A; B] := [T1; T2]%HV.
    Definition PS : preds_for _ [A; B] := [P1; P2].
    Compute (preds_hold (DS := [A; B]) PS TS).

    Context `{!genInG Σ Ω B [] }.
    Context `{!genInG Σ Ω A [A; B] }.

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
