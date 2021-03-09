(* This module defines the memory model or the memory subsystem. *)

From stdpp Require Import countable numbers gmap.
From iris.heap_lang Require Export locations.

From self.algebra Require Export view.

Section memory.

  (* We assume a type of values. *)
  Context {val : Type}.

  Implicit Types (v : val) (ℓ : loc).

  Inductive mem_event : Type :=
  | MEvAllocN ℓ (len : nat) v
  | MEvLoad ℓ v
  | MEvStore ℓ v
  (* Acquire/release weak memory events. *)
  | MEvLoadAcquire ℓ v
  | MEvStoreRelease ℓ v
  (* RMW are special *)
  | MEvRMW ℓ (vOld vNew : val) (* read-modify-write *)
  (* FIXME: Probably also need event for failed RMW. *)
  (* Persistent memory specific. *)
  | MEvWB ℓ
  | MEvFence
  | MEvFenceSync.

  Record message : Type := Msg {
    msg_val : val;
    msg_store_view : view;
    msg_persist_view : view;
  }.

  Record thread_view : Type := ThreadView {
    tv_store_view : view;
    tv_persist_view : view;
    tv_wb_buffer : view;
  }.

  Definition history : Type := gmap time message.

  Definition store := gmap loc history.

  Definition mem_config : Type := store * view.

  (* Takes a value and creates an initial history for that value. *)
  Definition initial_history P v : history := {[0 := Msg v ∅ P]}.

  (* Convert an array into a store. *)
  Fixpoint heap_array (l : loc) P (vs : list val) : store :=
    match vs with
    | [] => ∅
    | v :: vs' => {[l := initial_history P v]} ∪ heap_array (l +ₗ 1) P vs'
    end.

  Lemma heap_array_lookup (l : loc) P (vs : list val) (ow : history) (k : loc) :
    (heap_array l P vs : store) !! k = Some ow ↔
    (* True ↔ *)
    ∃ j w, (0 ≤ j)%Z ∧ k = l +ₗ j ∧ (ow = {[0 := Msg w ∅ P]}) ∧ vs !! (Z.to_nat j) = (Some w).
  Proof.
    revert k l; induction vs as [|v' vs IH]=> l' l /=.
    { rewrite lookup_empty. naive_solver lia. }
    rewrite -insert_union_singleton_l lookup_insert_Some IH. split.
    - intros [[-> ?] | (Hl & j & w & ? & -> & -> & ?)].
      { eexists 0, _. rewrite loc_add_0. naive_solver lia. }
      eexists (1 + j)%Z, _. rewrite loc_add_assoc !Z.add_1_l Z2Nat.inj_succ; auto with lia.
    - intros (j & w & ? & -> & -> & Hil). destruct (decide (j = 0)); simplify_eq/=.
      { rewrite loc_add_0; eauto. }
      right. split.
      { rewrite -{1}(loc_add_0 l). intros ?%(inj (loc_add _)); lia. }
      assert (Z.to_nat j = S (Z.to_nat (j - 1))) as Hj.
      { rewrite -Z2Nat.inj_succ; last lia. f_equal; lia. }
      rewrite Hj /= in Hil.
      eexists (j - 1)%Z, _. rewrite loc_add_assoc Z.add_sub_assoc Z.add_simpl_l.
      auto with lia.
  Qed.

  Lemma heap_array_map_disjoint (h : gmap loc history) P (l : loc) (vs : list val) :
    (∀ i, (0 ≤ i)%Z → (i < length vs)%Z → h !! (l +ₗ i) = None) →
    (heap_array l P vs) ##ₘ h.
  Proof.
    intros Hdisj. apply map_disjoint_spec=> l' v1 v2.
    intros (j&w&?&->&?&Hj%lookup_lt_Some%inj_lt)%heap_array_lookup.
    move: Hj. rewrite Z2Nat.id // => ?. by rewrite Hdisj.
  Qed.

  (* Initializes a region of the memory starting at [ℓ] *)
  Definition state_init_heap (ℓ : loc) (n : nat) P (v : val) (σ : store) : store :=
    heap_array ℓ P (replicate n v) ∪ σ.

  (* Small-step reduction steps on the memory. *)

  Inductive mem_step : mem_config → thread_view → mem_event → mem_config → thread_view → Prop :=
  (* Allocating a new location. *)
  | MStepAllocN σ V P B ℓ (len : nat) v p :
   (0 < len)%Z →
   (* (∀ i, (0 ≤ i)%Z → (i < n)%Z → σ.(heap) !! (l +ₗ i) = None) → *)
   (∀ idx, (0 ≤ idx)%Z → (idx < len)%Z → σ !! (ℓ +ₗ idx) = None) → (* This is a fresh segment of the heap not already in use. *)
    (* V' = <[ ℓ := 0 ]>V → (* V' incorporates the new event in the threads view. *) This may not be needed. *)
    mem_step (σ, p) (ThreadView V P B)
           (MEvAllocN ℓ len v)
           (state_init_heap ℓ len P v σ, p) (ThreadView V P B)
           (* (<[ℓ := {[ 0 := Msg v V' P ]}]>σ, p) (ThreadView V' P B) *)
  (* A normal non-atomic load. *)
  | MStepLoad σ V P B t ℓ (v : val) h p :
    σ !! ℓ = Some h →
    msg_val <$> (h !! t) = Some v →
    (default 0 (V !! ℓ)) ≤ t →
    mem_step (σ, p) (ThreadView V P B)
             (MEvLoad ℓ v)
             (σ, p) (ThreadView V P B)
             (* (σ, p) (ThreadView (<[ ℓ := t ]>V) P B) (* This variant includes the timestamp of the loaded msg. *) *)
  (* A normal non-atomic write. *)
  | MStepStore σ V P B t ℓ (v : val) h V' p :
    σ !! ℓ = Some h →
    (h !! t) = None → (* No event exists at t already. *)
    (V !!0 ℓ) ≤ t →
    V' = <[ℓ := t]>V → (* V' incorporates the new event in the threads view. *)
    mem_step (σ, p) (ThreadView V P B)
             (MEvStore ℓ v)
             (<[ℓ := <[t := Msg v ∅ P]>h]>σ, p) (ThreadView V' P B)
  (* An atomic acquire load. *)
  | MStepLoadAcquire σ V P B t ℓ (v : val) MV MP h p :
    σ !! ℓ = Some h →
    (h !! t) = Some (Msg v MV MP) →
    (V !!0 ℓ) ≤ t →
    mem_step (σ, p) (ThreadView V P B)
             (MEvLoadAcquire ℓ v)
             (σ, p) (ThreadView (V ⊔ MV) (P ⊔ MP) B) (* An acquire incorporates both the store view and the persistent view. *)
  (* An atomic release write. *)
  | MStepStoreRelease σ V P B t ℓ (v : val) h V' p :
    σ !! ℓ = Some h →
    (h !! t) = None → (* No event exists at t already. *)
    (V !!0 ℓ) ≤ t →
    V' = <[ ℓ := t ]>V → (* V' incorporates the new event in the threads view. *)
    mem_step (σ, p) (ThreadView V P B)
             (MEvStoreRelease ℓ v)
             (<[ℓ := <[t := Msg v V' P]>h]>σ, p) (ThreadView V' P B) (* A release releases both V' and P. *)
  (* Read-modify-write instructions. *)
  | MStepRMW σ ℓ h v MV MP V t V' P P' B p :
    σ !! ℓ = Some h →
    (h !! t) = Some (Msg v MV MP) → (* We read an event at time [t]. *)
    (V !!0 ℓ) ≤ t →
    (h !! (t + 1)) = None → (* The next timestamp is available, ensures that no other RMW read this event. *)
    V' = (<[ ℓ := t + 1 ]>(V ⊔ MV)) → (* V' incorporates the new event in the threads view. *)
    P' = P ⊔ MP →
    mem_step (σ, p) (ThreadView V P B)
             (MEvStoreRelease ℓ v)
             (<[ℓ := <[t := Msg v V' P']>h]>σ, p) (ThreadView V' P' B)
  (* Write-back instruction. *)
  | MStepWB σ V P B ℓ t h p :
    σ !! ℓ = Some h →
    V !! ℓ = Some t → (* An equality here _should_ be fine, the timestamps are only lower bounds anyway? *)
    mem_step (σ, p) (ThreadView V P B)
             (MEvWB ℓ)
             (σ, p) (ThreadView V (<[ℓ := t]>P) B)
  (* Asynchronous fence. *)
  | MStepFence σ V P B p :
    mem_step (σ, p) (ThreadView V P B)
             MEvFence
             (σ, p) (ThreadView V (P ⊔ B) ∅)
  (* Synchronous fence. *)
  | MStepFenceSync σ V P B p :
    mem_step (σ, p) (ThreadView V P B)
             MEvFence
             (σ, p ⊔ P) (ThreadView V (P ⊔ B) ∅).

  (* It is always possible to allocate a section of memory. *)
  Lemma alloc_fresh v (len : nat) σ p V P B :
    let ℓ := fresh_locs (dom (gset loc) σ) in (* ℓ is directly after the largest allocated location. *)
    (0 < len)%Z →
    mem_step (σ, p) (ThreadView V P B)
             (MEvAllocN ℓ len v)
             (state_init_heap ℓ len P v σ, p) (ThreadView V P B).
  Proof.
    intros. apply MStepAllocN; first done.
    intros. apply not_elem_of_dom.
    by apply fresh_locs_fresh.
  Qed.

End memory.