(* This is a variant of [durable_mp.v] where the flush and fence in the left
thread is moved to the right thread. *)

From iris.proofmode Require Import tactics.
From iris.algebra Require Import excl.
From Perennial.program_logic Require Import staged_invariant.

From self.base Require Import primitive_laws.
From self.lang Require Import lang.
From self.high Require Import dprop.

From self.lang Require Import notation lang.
From self.algebra Require Import view.
From self.base Require Import primitive_laws class_instances crash_borrow.
From self.high Require Import proofmode wpc_proofmode.
From self.high Require Import crash_weakestpre modalities weakestpre
     weakestpre_na weakestpre_at recovery_weakestpre protocol crash_borrow no_buffer
     abstract_state_instances locations protocol or_lost.
From self.high.modalities Require Import fence no_buffer.

Section program.

  Definition leftProg (x y : loc) : expr :=
    #x <-_NA #true ;;
    (* No flush or fence here. *)
    #y <-_AT #true.

  Definition rightProg (x y z : loc) : expr :=
    if: !_AT #y = #true
    then
      Flush #x ;;
      Fence ;;
      #z <-_NA #true
    else #().

  Definition prog (x y z : loc) : expr :=
    Fork (rightProg x y z) ;; leftProg x y.

  Definition recovery x z : expr :=
    if: !_NA z = #true
    then assert: !_NA x = #true
    else #().

End program.

Section proof.
  Context `{nvmFixedG Σ, nvmDeltaG Σ, inG Σ (exclR unitO)}.
  Context `{!stagedG Σ}.

  Context (x y z : loc) (γ__ex : gname).

  Program Definition inv_x : LocationProtocol bool :=
    {| pred (b : bool) v _ :=  ⌜v = #b⌝%I;
       bumper b := b; |}.
  Next Obligation. iIntros. by iApply post_crash_flush_pure. Qed.

  Definition pred_y (s : option bool) (v : val) (hG : nvmDeltaG Σ) :=
    match s with
      None => True
    | Some b =>
        match b with
          false => ⌜ v = #false ⌝ ∗ ⎡ own γ__ex (Excl ()) ⎤
        | true => ⌜ v = #true ⌝ ∗ store_lb x inv_x true
        end
    end%I.

  Program Definition prot_y := {| pred := pred_y; bumper _ := None; |}.
  Next Obligation.
    iIntros (???) "H /=". iApply post_crash_flush_nodep. done.
  Qed.
  Next Obligation. intros ? [|]; apply _. Qed.

  Program Definition inv_z :=
    {| pred (b : bool) (v : val) (hG : nvmDeltaG Σ) :=
        match b with
          false => ⌜ v = #false ⌝ ∗ ⎡ own γ__ex (Excl ()) ⎤
        | true => ⌜ v = #true ⌝ ∗ flush_lb x inv_x true
        end%I;
      bumper b := b; |}.
  Next Obligation.
    iIntros (? [|] ?); simpl.
    - iIntros "[% lb]". iCrashFlush.
      iDestruct "lb" as "(% & %le & ? & ?)".
      destruct s__pc; last done.
      iFrame "%".
      iApply persist_lb_to_flush_lb. iFrame.
    - iIntros "[% H]". iCrashFlush. iFrame. done.
  Qed.
  Next Obligation. intros ? [|]; apply _. Qed.


  (* Note: The recovery code does not use the [y] location, hence the crash
  condition does not mention [y] as we don't need it to be available after a
  crash. *)
  Definition crash_condition {hD : nvmDeltaG Σ} : dProp Σ :=
    ∃ (bx bz : bool),
      "#xPer" ∷ persist_lb x inv_x bx ∗
      "#zPer" ∷ persist_lb z inv_z bz ∗
      x ↦_{inv_x} [bx] ∗
      z ↦_{inv_z} [bz].

  Definition left_crash_condition {hD : nvmDeltaG Σ} : dProp Σ :=
    ∃ (bx : bool),
      "#xPer" ∷ persist_lb x inv_x bx ∗
      "xPts" ∷ x ↦_{inv_x} [bx].

  Definition right_crash_condition {hD : nvmDeltaG Σ} : dProp Σ :=
    ∃ (bz : bool),
      "#zPer" ∷ persist_lb z inv_z bz ∗
      "zPts" ∷ z ↦_{inv_z} [bz].

  Lemma left_crash_condition_impl {hD : nvmDeltaG Σ} (sx : list bool) :
    persist_lb x inv_x false -∗
    x ↦_{inv_x} sx -∗
    <PC> hD, left_crash_condition.
  Proof.
    iIntros "xPer xPts".
    iCrash.
    iDestruct "xPer" as (??) "[xPer #xRec]".
    iDestruct (crashed_in_if_rec with "xRec xPts") as (??) "[xPts xRec']".
    iDestruct (crashed_in_agree with "xRec xRec'") as %->.
    iExists _. iFrame "∗#".
  Qed.

  Lemma right_crash_condition_impl {hD : nvmDeltaG Σ} (sz : list bool) :
    persist_lb z inv_z false -∗
    z ↦_{inv_z} sz -∗
    <PC> hD, right_crash_condition.
  Proof.
    iIntros "zPer zPts".
    iCrash.
    iDestruct "zPer" as (??) "[zPer #zRec]".
    iDestruct (crashed_in_if_rec with "zRec zPts") as (??) "[zPts zRec']".
    iDestruct (crashed_in_agree with "zRec zRec'") as %->.
    iExists _. iFrame "∗#".
  Qed.

  (* Prove right crash condition. *)
  Ltac whack_right_cc :=
    iSplit;
    first iApply (right_crash_condition_impl with "zPer zPts").

  Ltac whack_left_cc :=
    iSplit;
    first iApply (left_crash_condition_impl with "xPer xPts").

  Lemma no_flush_or (P : dProp Σ) Q : <noflush> (P ∨ Q) ⊣⊢ <noflush> P ∨ <noflush> Q.
  Proof. iModel. rewrite !no_flush_at. rewrite monPred_at_or. naive_solver. Qed.

  Global Instance into_no_flush_or (P P' Q Q' : dProp Σ) :
    IntoNoFlush P P' → IntoNoFlush Q Q' → IntoNoFlush (P ∨ Q)%I (P' ∨ Q')%I.
  Proof. rewrite /IntoNoFlush no_flush_or. by intros <- <-. Qed.

  Lemma right_prog_spec s E1 :
    store_lb y prot_y (Some false) -∗
    ⎡ is_at_loc y ⎤ -∗
    persist_lb z inv_z false -∗
    z ↦_{inv_z} [false] -∗
    WPC rightProg x y z @ s; E1
    {{ v, z ↦_{inv_z} [false; true] ∨ z ↦_{inv_z} [false] }}
    {{ <PC> _, right_crash_condition }}.
  Proof.
    iIntros "#yLb #yShared #zPer zPts".
    (* Evaluate the first load. *)
    rewrite /rightProg.
    wpc_bind (!_AT _)%E.
    iApply wpc_atomic_no_mask. whack_right_cc.
    iApply (wp_load_at _ _ (λ s v, (⌜v = #true⌝ ∗ store_lb x inv_x true) ∨ ⌜v = #false⌝)%I prot_y with "[$yShared $yLb]").
    { iModIntro. iIntros (?? incl) "a". rewrite /prot_y.
      destruct s' as [[|]|]; last done.
      - iDestruct "a" as "[% #?]". iFrame "#". naive_solver.
      - iDestruct "a" as "[% O]". naive_solver. }
    iNext.
    iIntros (??) "[yLb' disj]".
    iDestruct (post_fence_extract' _ (⌜v = #true ∨ v = #false⌝)%I with "disj []") as %[-> | ->].
    { iIntros "[[-> _]|->]"; naive_solver. }
    2: {
      (* We loaded [false] and this case is trivial. *)
      whack_right_cc.
      iModIntro.
      wpc_pures.
      { iApply (right_crash_condition_impl with "zPer zPts"). }
      iModIntro.
      iRight. iFrame. }
    (* We loaded [true]. *)
    whack_right_cc.
    iModIntro.
    wpc_pures.
    { iApply (right_crash_condition_impl with "zPer zPts"). }

    (* Flush *)
    wpc_bind (Flush _)%E.
    iApply wpc_atomic_no_mask.
    whack_right_cc.

    iDestruct (post_fence_flush_free with "disj") as "[[_ storeLb] | %eq]";
      last inversion eq.

    iApply (wp_flush_lb with "storeLb").
    iNext.
    iIntros "#xLb".
    whack_right_cc.
    iModIntro.
    wpc_pures;
      first iApply (right_crash_condition_impl with "zPer zPts").

    wpc_bind (Fence).
    iApply wpc_atomic_no_mask. whack_right_cc.
    iApply wp_fence. do 2 iModIntro.
    (* iDestruct "disj" as "[[_ #xLb] | %]"; last congruence. *)
    whack_right_cc.
    iModIntro.
    wpc_pures.
    { iApply (right_crash_condition_impl with "zPer zPts"). }

    iApply wpc_atomic_no_mask. whack_right_cc.
    iApply (wp_store_na _ inv_z _ _ _ true with "[$zPts]"); eauto.
    { simpl. iFrame "xLb". done. }

    iIntros "!> zPts /=".
    whack_right_cc.
    iModIntro.
    iLeft. iFrame.
  Qed.

  Lemma prog_spec :
    ⎡ pre_borrow ⎤ ∗
    (* know_protocol x inv_x ∗ know_protocol y prot_y ∗ know_protocol z inv_z ∗ *)
    persist_lb x inv_x false ∗
    x ↦_{inv_x} [false] ∗
    store_lb y prot_y (Some false) ∗
    ⎡ is_at_loc y ⎤ ∗
    persist_lb z inv_z false ∗
    z ↦_{inv_z} [false] -∗
    WPC prog x y z @ ⊤
    {{ v, True }}
    {{ <PC> _, crash_condition }}.
  Proof.
    iIntros "(pb & #xPer & xPts & #yLb & #yShared & #zPer & zPts)".
    rewrite /prog.

    (* We create a crash borrow in order to transfer resources to the forked
    thread. *)
    iApply (wpc_crash_borrow_inits _ _ _ _ _ (<PC> _, right_crash_condition)%I
             with "pb [zPts]").
    { iAccu. }
    { iModIntro. iIntros "zPts".
      iApply (right_crash_condition_impl with "zPer zPts"). }
    iIntros "cb".

    iApply (wpc_crash_mono _ _ _ _ _ (<PC> _, left_crash_condition)%I).
    { iIntros "L R".
      iCrash.
      iNamed "L".
      iNamed "R".
      iExists _, _.
      iFrame "∗#". }
    Unshelve. 2: { apply _. }

    wpc_bind (Fork _)%E.
    iApply (wpc_fork with "[cb]").
    - (* Show safety of the forked off thread. *)
      iApply (wpc_crash_borrow_open_modify with "cb"); first done.
      iNext. iSplit; first done.
      iIntros "zPts".

      iDestruct (right_prog_spec with "yLb yShared zPer zPts") as "wp".
      iApply (wpc_mono' with "[] [] wp"); last naive_solver.
      iIntros (?) "[zPts | zPts]".
      * iExists (z ↦_{_} (_ : list bool)). iFrame.
        iSplit; last naive_solver.
        iIntros "!> zPts".
        iApply (right_crash_condition_impl with "zPer zPts").
      * iExists (z ↦_{_} (_ : list bool)). iFrame.
        iSplit; last naive_solver.
        iIntros "!> zPts".
        iApply (right_crash_condition_impl with "zPer zPts").
    - whack_left_cc. iNext.
      wpc_pures.
      { iApply (left_crash_condition_impl with "xPer xPts"). }
      rewrite /leftProg.
      wpc_bind (_ <-_NA _)%E.
      iApply wpc_atomic_no_mask. whack_left_cc.
      iApply (wp_store_na x _ _ _ _ true with "[$xPts]").
      { reflexivity. } { done. }
      { rewrite /inv_x. done. }
      simpl.
      iNext. iIntros "xPts".
      whack_left_cc.
      iModIntro.
      wpc_pures;
        first iApply (left_crash_condition_impl with "xPer xPts").

      iDestruct (mapsto_na_store_lb with "xPts") as "#xStoreLb";
        first reflexivity.
      wpc_bind (_ <-_AT _)%E.
      iApply wpc_atomic_no_mask. whack_left_cc.
      iApply (wp_store_at _ (Some false) (Some true)).
      { iFrame.
        iPureGoal. { done. }
        iFrame "#".
        iSplitL.
        - iModIntro. simpl. naive_solver.
        - iIntros (? s_c v_c). simpl.
          destruct s_c as [[|]|]; [naive_solver| |naive_solver].
          iIntros "? ([? O1] & [??] & [? O2])".
          by iDestruct (own_valid_2 with "O1 O2") as %HI%exclusive_l. }
      iIntros "!> yLb2".
      whack_left_cc.
      done.
  Qed.

End proof.
