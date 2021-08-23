(* A collection of a few fairly general constructions and lemmas. In other
words, our own little (std++)++. *)

From stdpp Require Import countable numbers gmap fin_maps list.
From iris Require Import cmra.
From iris.bi Require Import big_op.
From iris.algebra Require Import gmap agree big_op.
From iris.proofmode Require Import tactics.
Import interface.bi derived_laws.bi derived_laws_later.bi.

From iris.bi Require Import derived_laws_later.

(* We define our own relation. Workaround for universe issues in stdpp and Iris. *)
Definition relation2 A := A -> A -> Prop.

(* Lemmas about finite maps of natural numbers. *)
Section nat_map.
  Context `{FinMap nat M} {A : Type}.

  Implicit Types m : M A.

  Definition max_member m t v :=
    (m !! t = Some v) ∧ (∀ t', t < t' → m !! t' = None).

  (** Expresses that the map [m] contains, in order, the values [xs] from the
  indeces starting at exactly [lo] ending at exactly [hi]. *)
  Fixpoint map_slice m (lo hi : nat) (xs : list A) :=
    match xs with
    | [] => False
    | [x] => m !! hi = Some x ∧ lo = hi
    | x :: xs =>
      m !! lo = Some x ∧
      ∃ lo',
        lo < lo' ∧
        (∀ lo'', lo < lo'' < lo' → m !! lo'' = None) ∧ (* There are no elements in between. *)
        map_slice m lo' hi xs
    end.

  Lemma map_slice_lookup_between m lo hi xs t x :
    map_slice m lo hi xs → lo ≤ t ≤ hi → m !! t = Some x → x ∈ xs.
  Proof.
    generalize dependent m. generalize dependent lo. generalize dependent hi.
    induction xs as [|x1 xs IH]; first done. (* Base case is trivial. *)
    intros hi lo m.
    (* We destruct [xs] to handle the special case where the list is a singleton. *)
    destruct xs as [|x2 xs].
    - intros [mLook ->] ? ?.
      apply elem_of_list_singleton.
      assert (t = hi) as -> by lia.
      congruence.
    - intros (mLook & lo' & ? & between & slice) ? ?.
      assert (lo = t ∨ lo < t) as [eq | gt] by lia.
      * simplify_eq. apply elem_of_list_here.
      * apply elem_of_list_further.
        assert (t < lo' ∨ lo' ≤ t) as [lt | ge] by lia.
        { assert (m !! t = None) by (apply between; lia). congruence. }
        eapply IH; [apply slice | lia | done].
  Qed.

  Lemma map_slice_lookup_lo m lo hi xs :
    map_slice m lo hi xs → m !! lo = xs !! 0.
  Proof.
    destruct xs as [|x xs]; [done|]. simpl.
    destruct xs.
    - intros [? ->]. done.
    - intros [? _]. done.
  Qed.

  Lemma map_slice_nonempty m lo hi xs : map_slice m lo hi xs → xs ≠ [].
  Proof. by destruct xs. Qed.

  Lemma map_slice_lookup_hi m lo hi xs :
    map_slice m lo hi xs → m !! hi = last xs.
  Proof.
    generalize dependent lo. generalize dependent hi.
    induction xs as [|x xs IH]; [done|].
    intros hi lo. simpl.
    destruct xs as [|x' xs].
    - intros [? ->]. done.
    - intros [? [lo' Hh]]. apply (IH hi lo').
      apply Hh.
  Qed.

  Lemma map_slice_lookup_hi_alt m lo hi xs :
    map_slice m lo hi xs → ∃ x, m !! hi = Some x ∧ last xs = Some x.
  Proof.
    intros ?.
    assert (is_Some (last xs)) as [x eq].
    { apply last_is_Some. eapply map_slice_nonempty. done. }
    exists x. split; last done. rewrite -eq. by eapply map_slice_lookup_hi.
  Qed.

End nat_map.

(* This section has been upstreamed. *)
(* Section max_list. *)
(*   (* Context {A : Type}. *) *)

(*   Lemma max_list_elem_of_le n ns: *)
(*     n ∈ ns → n ≤ max_list ns. *)
(*   Proof. induction 1; simpl; lia. Qed. *)

(*   Lemma max_list_elem_of ns : ns ≠ [] → max_list ns ∈ ns. *)
(*   Proof. *)
(*     intros H. induction ns; [done|]. simpl. *)
(*     edestruct (Nat.max_spec a) as [[Hle ->]|[HO ->]]. *)
(*     - destruct ns; [simpl in *; lia|]. *)
(*       by apply elem_of_list_further, IHns. *)
(*     - apply elem_of_list_here. *)
(*   Qed. *)

(*   Lemma max_list_not_elem_of_gt n ns : max_list ns < n → n ∉ ns. *)
(*   Proof. intros ?. induction 1; simpl in *; lia. Qed. *)

(* End max_list. *)

Lemma singleton_included_insert `{Countable K} {A : cmra} (k : K) (a a' : A) (m : gmap K A) :
  a ≼ a' → {[k := a]} ≼ <[k:=a']> m.
Proof.
  intros le.
  apply singleton_included_l.
  exists a'.
  split. - by rewrite lookup_insert. - apply Some_included. right. done.
Qed.

Lemma big_sepM_imap {PROP : bi} `{Countable K} {A B} (f : K → A → B) (Φ : K → B → PROP) (m : gmap K A) :
  ([∗ map] k↦y ∈ map_imap (λ (k : K) a, Some (f k a)) m, Φ k y) ⊣⊢ ([∗ map] k↦y ∈ m, Φ k (f k y)).
Proof. Admitted.

Lemma big_sepM_impl' {PROP : bi} `{Countable K} {A B} (Φ : K → A → PROP) (Ψ : K → B → PROP) (m1 : gmap K A) (m2 : gmap K B) :
  dom (gset K) m1 = dom _ m2 →
  ([∗ map] k↦x ∈ m1, Φ k x) -∗
  □ (∀ (k : K) (x : A) (y : B), ⌜m1 !! k = Some x⌝ → ⌜m2 !! k = Some y⌝ → Φ k x -∗ Ψ k y) -∗
  [∗ map] k↦y ∈ m2, Ψ k y.
Proof. Admitted.

Lemma map_Forall_singleton `{FinMap K M} {A} (j : K) (y : A) (P : K → A → Prop) :
  P j y ↔
  map_Forall P ({[j := y]} : M A).
Proof.
  split; intros HP.
  - by intros i x [-> ->]%lookup_singleton_Some.
  - apply HP, lookup_singleton.
Qed.

Lemma map_Forall_singleton' `{FinMap K M} {A} (j : K) (y : A) (P : K → A → Prop) :
  P j y ↔
  map_Forall (λ (i : K) (x : A), P i x) ({[j := y]} : M A).
Proof.
  split; intros HP.
  - by intros i x [-> ->]%lookup_singleton_Some.
  - apply HP, lookup_singleton.
Qed.

Lemma option_not_included_None {A : cmra} (x : A) : ¬ (Some x ≼ None).
Proof. intros [[y|] eq]; inversion eq. Qed.

Lemma to_agree_fmap (a b : gmap nat positive) :
  a ⊆ b ↔ to_agree <$> a ≼ to_agree <$> b.
Proof.
  rewrite lookup_included.
  rewrite  map_subseteq_spec.
  setoid_rewrite lookup_fmap.
  split.
  - intros sub.
    intros i.
    (* apply option_included_total. *)
    destruct (a !! i) eqn:eq.
    2: { eexists _. rewrite left_id. reflexivity. }
    rewrite (sub i p); done.
  - intros incl.
    intros i.
    destruct (a !! i) eqn:eq.
    2: { done. }
    intros x [= ->].
    specialize (incl i).
    setoid_rewrite eq in incl.
    simpl in incl.
    destruct (b !! i) eqn:eq'.
    2: { apply option_not_included_None in incl. done. }
    simpl in incl.
    setoid_rewrite Some_included_total in incl.
    setoid_rewrite to_agree_included in incl.
    setoid_rewrite incl.
    done.
Qed.

Section big_sepM.
  Context {PROP : bi}.
  Context `{BiAffine PROP}.
  Context `{Countable K} {A : Type}.
  Implicit Types m : gmap K A.
  Implicit Types Φ Ψ : K → A → PROP.

  Lemma big_sepM_impl Φ Ψ m :
    ([∗ map] k↦x ∈ m, Φ k x) -∗
    □ (∀ k x, ⌜m !! k = Some x⌝ → Φ k x -∗ Ψ k x) -∗
    [∗ map] k↦x ∈ m, Ψ k x.
  Proof.
    apply wand_intro_l. rewrite big_sepM_intro -big_sepM_sep.
    by setoid_rewrite wand_elim_l.
  Qed.

End big_sepM.

Section map_zip_with.
  Context `{FinMap K M}.

  (* Upstream this. *)
  Lemma map_zip_with_dom_fst `{FinMapDom K M D} {A B C}
        (f : A → B → C) (ma : M A) (mb : M B) : dom D (map_zip_with f ma mb) ⊆ dom D ma.
  Proof.
    intros ?. rewrite 2!elem_of_dom. intros [? ?%map_lookup_zip_with_Some].
    naive_solver.
  Qed.

  Lemma map_zip_with_dom_snd `{FinMapDom K M D} {A B C}
        (f : A → B → C) (ma : M A) (mb : M B) : dom D (map_zip_with f ma mb) ⊆ dom D mb.
  Proof. rewrite map_zip_with_flip. apply map_zip_with_dom_fst. Qed.

  (* upstreamed *)
  Lemma map_zip_with_dom `{FinMapDom K M D} {A B C}
        (f : A → B → C) (ma : M A) (mb : M B) :
    dom D (map_zip_with f ma mb) ≡ dom D ma ∩ dom D mb.
  Proof.
    rewrite set_equiv=> x.
    rewrite elem_of_intersection.
    rewrite !elem_of_dom.
    rewrite map_lookup_zip_with.
    destruct (ma !! x), (mb !! x); rewrite !is_Some_alt; naive_solver.
  Qed.

  Lemma map_zip_with_dom_eq_l `{FinMapDom K M D} {A B C}
        (f : A → B → C) (ma : M A) (mb : M B) :
    dom D ma ⊆ dom D mb →
    dom D (map_zip_with f ma mb) ≡ dom D ma.
  Proof. rewrite map_zip_with_dom. set_solver. Qed.

  Lemma map_zip_with_dom_eq_r `{FinMapDom K M D} {A B C}
        (f : A → B → C) (ma : M A) (mb : M B) :
    dom D mb ⊆ dom D ma →
    dom D (map_zip_with f ma mb) ≡ dom D mb.
  Proof. rewrite map_zip_with_dom. set_solver. Qed.

End map_zip_with.

Definition restrict `{FinMap K M, ElemOf K D, !RelDecision (∈@{D})} {A} (s : D) (m : M A) :=
  filter (λ '(k, _), k ∈ s) m.

Section restrict.
  Context `{FinMapDom K M D}.
  Context `{!RelDecision (∈@{D})}.
  Context {A : Type}.
  Implicit Types (s : D) (m : M A) (k : K).

  Lemma restrict_lookup_Some (s : D) (m : M A) (k : K) (x : A) :
    restrict s m !! k = Some x ↔ (m !! k = Some x) ∧ k ∈ s.
  Proof. by rewrite map_filter_lookup_Some. Qed.

  Lemma restrict_lookup_Some_2 (s : D) (m : M A) (k : K) (x : A) :
    m !! k = Some x → k ∈ s → restrict s m !! k = Some x.
  Proof. by rewrite restrict_lookup_Some. Qed.

  (* Upstreamed. *)
  Lemma map_filter_subseteq f `{∀ (x : (K *A)), Decision (f x)} m :
    filter f m ⊆ m.
  Proof. apply map_subseteq_spec, map_filter_lookup_Some_1_1. Qed.

  Lemma restrict_subseteq s m : restrict s m ⊆ m.
  Proof. rewrite /restrict. apply map_filter_subseteq. Qed.

  Lemma restrict_intersection s m : dom _ (restrict s m) = s ∩ (dom _ m).
  Proof. Abort. (* This is true, but we haven't needed it yet. *)

  (*
  Lemma restrict_superset_id (s : D) (m : M A) :
    dom _ m ⊆ s → restrict s m = m.
  Proof.
    intros Hsub.
  Admitted.
  *)

  Lemma restrict_dom s m : dom _ (restrict s m) ≡ s ∩ dom _ m.
  Proof.
    apply dom_filter => i.
    rewrite elem_of_intersection.
    rewrite elem_of_dom.
    rewrite /is_Some.
    naive_solver.
  Qed.

  Lemma restrict_dom_subset (s : D) (m : M A) :
    s ⊆ dom _ m → dom _ (restrict s m) ≡ s.
  Proof. rewrite restrict_dom. set_solver. Qed.

End restrict.

Section restrict_leibniz.
  Context `{FinMapDom K M D}.
  Context `{!RelDecision (∈@{D})}.
  Context {A : Type}.
  Context `{!LeibnizEquiv D}.

  Lemma restrict_dom_subset_L (s : D) (m : M A) :
    s ⊆ dom _ m → dom _ (restrict s m) = s.
  Proof. unfold_leibniz. apply restrict_dom_subset. Qed.

End restrict_leibniz.

Lemma valid_to_agree_fmap `{Countable K} {B : ofe} (m : gmap K B) :
  ✓ (to_agree <$> m : gmapUR _ _).
Proof. intros ℓ. rewrite lookup_fmap. by case (m !! ℓ). Qed.

Section big_sepM2.
  Context {PROP : bi}.
  Context `{Countable K} {A B : Type}.
  Implicit Types Φ Ψ : K → A → B → PROP.

  Lemma big_sepM2_impl_subseteq `{!BiAffine PROP} (m1 n1 : gmap K A) (m2 n2 : gmap K B) Φ :
    n1 ⊆ m1 →
    n2 ⊆ m2 →
    dom (gset _) n1 ≡ dom _ n2 →
    ([∗ map] k↦y1;y2 ∈ m1;m2, Φ k y1 y2) -∗
    [∗ map] k↦y1;y2 ∈ n1;n2, Φ k y1 y2.
  Proof.
    rewrite 2!big_sepM2_alt.
    iIntros (sub sub' eq) "[%impl map]".
    iSplit.
    - setoid_rewrite <- elem_of_dom. rewrite -set_equiv. done.
    - iDestruct (big_sepM_impl_dom_subseteq with "map []") as "[$ temp]".
      { rewrite 2!map_zip_with_dom.
        apply subseteq_dom in sub.
        apply subseteq_dom in sub'.
        set_solver. }
      iModIntro.
      setoid_rewrite map_subseteq_spec in sub.
      setoid_rewrite map_subseteq_spec in sub'.
      iIntros (? [??] [??] [? ?]%map_lookup_zip_Some
               [look1%sub look2%sub']%map_lookup_zip_Some).
      naive_solver.
  Qed.

End big_sepM2.
