From iris.proofmode Require Import tactics.

From self.base Require Import primitive_laws.
From self.lang Require Import lang.
From self.high Require Import dprop.

From self.lang Require Import notation lang.
From self.algebra Require Import view.
From self.base Require Import primitive_laws class_instances crash_borrow.
From self.high Require Import proofmode wpc_proofmode.
From self.high Require Import crash_weakestpre modalities weakestpre
     weakestpre_at recovery_weakestpre protocol crash_borrow no_buffer.

Section program.

  Definition leftProg (x y : loc) : expr :=
    #x <- #true ;;
    WB #x ;;
    Fence ;;
    #y <-{rel} #true.

  Definition rightProg (y z : loc) : expr :=
    if: !{acq} #y = #true
    then Fence ;; #z <- #true
    else #().

  Definition prog (x y z : loc) : expr :=
    Fork (rightProg y z) ;; leftProg x y.

  Definition recovery x z : expr :=
    if: ! z = #true
    then assert: ! x = #true
    else #().

End program.

Section proof.
  Context `{nvmFixedG Σ, nvmDeltaG Σ}.

  Context (x y z : loc).

  Definition inv_x (b : bool) (v : val) (hG : nvmDeltaG Σ) : dProp Σ :=
    ⌜v = #(Nat.b2n b)⌝.

  Program Instance : LocationProtocol inv_x := { bumper n := n }.
  Next Obligation. iIntros. by iApply post_crash_flush_pure. Qed.
  Next Obligation. iIntros (???) "? !> //". Qed.

  Definition inv_y (b : bool) (v : val) (hG : nvmDeltaG Σ) : dProp Σ :=
    match b with
      false => ⌜ v = #false ⌝
    | true => ⌜ v = #true ⌝ ∗ know_flush_lb x true
    end.

  Program Instance : LocationProtocol inv_y := { bumper n := n }.
  Next Obligation.
    iIntros (? [|] ?); simpl.
    - iIntros "[% lb]". iCrashFlush.
      iDestruct "lb" as "(% & %le & h & hi & _)".
      destruct s__pc; last done.
      iFrame "∗%".
    - iIntros "%". iApply post_crash_flush_pure. done.
  Qed.
  Next Obligation.
    rewrite /inv_y. iIntros (???) "H". iModIntro. done.
  Qed.

  Definition inv_z := inv_y.
  (* Definition inv_z (b : bool) (v : val) (hG : nvmDeltaG Σ) : dProp Σ := *)
  (*   ⌜v = #(Nat.b2n b)⌝ ∗ (⌜b = true⌝ -∗ know_flush_lb x true). *)

  Definition crash_condition {hD : nvmDeltaG Σ} : dProp Σ :=
    ∃ (sx sz : list bool),
      "#xProt" ∷ know_protocol x inv_x ∗
      "#yProt" ∷ or_lost y (know_protocol y inv_y) ∗
      "#yShared" ∷ or_lost y (⎡ is_shared_loc y ⎤) ∗
      "#zProt" ∷ know_protocol z inv_z ∗
      x ↦ₚ sx ∗
      z ↦ₚ sz.

  Definition right_crash_condition {hD : nvmDeltaG Σ} : dProp Σ :=
    ∃ (sz : list bool),
      "#yProt" ∷ or_lost y (know_protocol y inv_y) ∗
      "#yShared" ∷ or_lost y (⎡ is_shared_loc y ⎤) ∗
      "#zProt" ∷ know_protocol z inv_z ∗
      z ↦ₚ sz.

  (* Lemma crash_condition_impl {hD : nvmDeltaG Σ} (ssX ssZ : list bool) : *)
  (*   know_protocol x inv_x -∗ know_protocol y inv_y -∗ know_protocol z inv_z -∗ *)
  (*   x ↦ₚ ssX -∗ *)
  (*   ⎡ is_shared_loc y ⎤ -∗ *)
  (*   z ↦ₚ ssZ -∗ *)
  (*   <PC> hG, crash_condition. *)
  (* Proof. *)
  (*   iIntros "xPred yProt zProt xPts yShared zPts". *)
  (*   iCrash. *)
  (*   iDestruct "xPts" as (??) "[xPts xRec]". *)
  (*   iDestruct "zPts" as (??) "[zPts zRec]". *)
  (*   iExists _, _. *)
  (*   iDestruct (recovered_at_or_lost with "xRec xPred") as "xPred". *)
  (*   iDestruct (recovered_at_or_lost with "zRec zProt") as "zProt". *)
  (*   iFrame. *)
  (* Qed. *)

  Lemma right_crash_condition_impl {hD : nvmDeltaG Σ} (ssZ : list bool) :
    know_protocol y inv_y -∗
    know_protocol z inv_z -∗
    know_store_lb y false -∗
    ⎡ is_shared_loc y ⎤ -∗
    z ↦ₚ ssZ -∗
    <PC> hD, right_crash_condition.
  Proof.
    iIntros "yProt zProt yLb yShared zPts".
    iCrash.
    iDestruct "zPts" as (??) "[zPts zRec]".
    iExists _.
    iDestruct (recovered_at_or_lost with "zRec zProt") as "zProt".
    iFrame.
  Qed.

  (* Prove right crash condition. *)
  Ltac whack_right_cc :=
    iSplit;
    first iApply (right_crash_condition_impl with "yProt zProt yLb yShared zPts").

  Lemma right_prog_spec s k E1 :
    know_protocol y inv_y -∗
    know_protocol z inv_z -∗
    know_store_lb y false -∗
    ⎡ is_shared_loc y ⎤ -∗
    z ↦ₚ [false] -∗
    WPC rightProg y z @ s; k; E1
    {{ v, z ↦ₚ [false; true] ∨ z ↦ₚ [false] }}
    {{ <PC> _, right_crash_condition }}.
  Proof.
    iIntros "#yProt #zProt #yLb #yShared zPts".
    (* Evaluate the first load. *)
    rewrite /rightProg.
    wpc_bind (!{acq} _)%E.
    iApply wpc_atomic_no_mask. whack_right_cc.
    iApply (wp_load_shared _ _ (λ s v, (⌜v = #true⌝ ∗ know_flush_lb x true) ∨ ⌜v = #false⌝)%I inv_y with "[$yProt $yShared $yLb]").
    { iModIntro. iIntros (?? incl) "a". rewrite /inv_y.
      destruct s'.
      - iDestruct "a" as "[% #?]". iFrame "#". naive_solver.
      - iDestruct "a" as "%". naive_solver. }
    iNext.
    iIntros (??) "[yLb' disj]".
    iDestruct (post_fence_extract' _ (⌜v = #true ∨ v = #false⌝)%I with "disj []") as %[-> | ->].
    { iIntros "[[-> _]|->]"; naive_solver. }
    2: {
      (* We loaded [false] and this case is trivial. *)
      whack_right_cc.
      iModIntro.
      wpc_pures.
      { iApply (right_crash_condition_impl with "yProt zProt yLb yShared zPts"). }
      iModIntro.
      iRight. iFrame. }
    (* We loaded [true]. *)
    whack_right_cc.
    iModIntro.
    wpc_pures.
    { iApply (right_crash_condition_impl with "yProt zProt yLb yShared zPts"). }
    wpc_bind (Fence).
    iApply wpc_atomic_no_mask. whack_right_cc.
    iApply (wp_fence with "disj").
    iNext.
    iDestruct 1 as "[[_ #xLb] | %]"; last congruence.
    whack_right_cc.
    iModIntro.
    wpc_pures.
    { iApply (right_crash_condition_impl with "yProt zProt yLb yShared zPts"). }

    iApply wpc_atomic_no_mask. whack_right_cc.
    iApply (wp_store_ex _ _ _ _ _ true inv_z with "[$zPts $zProt]").
    { reflexivity. }
    { done. }
    { simpl. iFrame "xLb". done. }

    iIntros "!> zPts /=".
    whack_right_cc.
    iModIntro.
    iLeft. iFrame.
  Qed.

  Lemma prog_spec k :
    ⎡ pre_borrow ⎤ ∗
    know_protocol x inv_x ∗ know_protocol y inv_y ∗ know_protocol z inv_z ∗
    x ↦ₚ [false] ∗
    know_store_lb y false ∗
    ⎡ is_shared_loc y ⎤ ∗
    z ↦ₚ [false] -∗
    WPC  prog x y z
    @ k; ⊤
    {{ v, True }}
    {{ <PC> _, crash_condition }}.
  Proof.
    iIntros "(pb & #xProt & #yProt & #zProt & xPts & #yLb & #yShared & zPts)".
    (* iIntros "H". *)
    rewrite /prog.

    (* We create a crash borrow in order to transfer resources to the forked
    thread. *)
    iApply (wpc_crash_borrow_inits _ _ _ _ _ _ (<PC> _, right_crash_condition)%I with "pb [zPts]").
    { iAccu. }
    { iModIntro. iIntros "zPts".
      iDestruct "zProt" as "-#zProt".
      iDestruct "yProt" as "-#yProt".
      iDestruct "yShared" as "-#yShared".
      iCrash.
      iDestruct "zPts" as (??) "[zPts zRec]".
      iDestruct (recovered_at_or_lost with "zRec zProt") as "zProt".
      iExists _. iFrame. }
    iIntros "cb".

    wpc_bind (Fork _)%E.
    iApply (wpc_fork with "[cb]").
    { (* Show safety of the forked off thread. *)
      iApply (wpc_crash_borrow_open_modify with "cb"); first done.
      iNext. iSplit; first done.
      iIntros "zPts". rewrite (left_id True%I (∗)%I).

      iDestruct (right_prog_spec with "yProt zProt yLb yShared zPts") as "wp".
      iApply (wpc_mono' with "[] [] wp"); last naive_solver.
      iIntros (?) "[zPts | zPts]".
      - iExists (z ↦ₚ (_ : list bool)). iFrame.
        iSplit; last naive_solver.
        iIntros "!> zPts".
        iApply (right_crash_condition_impl with "yProt zProt yLb yShared zPts").
      - iExists (z ↦ₚ (_ : list bool)). iFrame.
        iSplit; last naive_solver.
        iIntros "!> zPts".
        iApply (right_crash_condition_impl with "yProt zProt yLb yShared zPts").
    }
    { admit. }
  Abort.

End proof.
