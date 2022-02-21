(* Resource algebra to represent abstract histories. *)

From iris.bi Require Import lib.fractional.
From iris.algebra Require Import auth gmap.
From iris.base_logic.lib Require Import own.
From iris.heap_lang Require Export locations.
From iris.proofmode Require Import proofmode.

From self.algebra Require Import ghost_map.
From self.lang Require Import lang.
From self Require Import extra.
From self.high.resources Require Import auth_map_map.

(* For abstract history we need two types of fragmental knowledge. One that
represents ownership about the entire abstract history of a location (for
non-atomic) and one that represents only knowledge about one entry in the
abstract history. *)

(* Resource algebras that for each location stores the encoded abstract states
associated with each message/store. *)
Definition encoded_abs_historyR := gmapUR time (agreeR positiveO).

Definition know_abs_historiesR := auth_map_mapR positiveO.

(** We define a few things about the resource algebra that that we use to encode
abstract histories. *)
Section abs_history_lemmas.
  Context `{!ghost_mapG Σ loc (gmap time positive), inG Σ know_abs_historiesR}.
  Context `{Countable ST}.

  Implicit Types
    (abs_hist : gmap time ST) (ℓ : loc)
    (enc_abs_hist : gmap time positive)
    (abs_hists : gmap loc (gmap time positive)).

  Definition abs_hist_to_ra abs_hist : encoded_abs_historyR :=
    (to_agree ∘ encode) <$> abs_hist.

  (* If we own the full history then we own the authorative view of both the
  resource algebras. *)
  Definition own_full_history γ1 γ2 abs_hists : iProp Σ :=
    ghost_map_auth γ1 (DfracOwn 1) abs_hists ∗
    auth_map_map_auth γ2 abs_hists.

  Definition own_frag_encoded_history_loc γ2 ℓ enc_abs_hist : iProp Σ :=
    auth_map_map_frag γ2 {[ ℓ := enc_abs_hist ]}.

  (* In this definition we store that decoding the stored encoded histry is
  equal to our abstract history. This is weaker than strogin the other way
  around, namely that encoding our history is equal to the stored encoded
  history. Storing this weaker fact makes the definition easier to show. This is
  important for the load lemma where, when we load some state and we want to
  return [store_lb] for the returned state. At that point we can conclude that
  decoding the encoding gives a result but not that the encoding is an encoding
  of some state. *)
  Definition own_frag_history_loc γ ℓ abs_hist : iProp Σ :=
    ∃ enc,
      ⌜decode <$> enc = Some <$> abs_hist⌝ ∗
      own_frag_encoded_history_loc γ ℓ enc.

  Definition own_full_encoded_history_loc γ1 γ2 ℓ q enc_abs_hist : iProp Σ :=
    ℓ ↪[ γ1 ]{#q} enc_abs_hist ∗
    own_frag_encoded_history_loc γ2 ℓ enc_abs_hist.

  Definition own_full_history_loc γ1 γ2 ℓ q abs_hist : iProp Σ :=
    own_full_encoded_history_loc γ1 γ2 ℓ q (encode <$> abs_hist).

  Global Instance own_full_encoded_history_fractional γ1 γ2 ℓ enc_abs_hist :
    Fractional (λ q, own_full_encoded_history_loc γ1 γ2 ℓ q enc_abs_hist).
  Proof.
    intros p q.
    rewrite /own_full_encoded_history_loc.
    iSplit.
    - iIntros "[[$$] #?]". iFrame "#".
    - iIntros "[[$ $] [$ _]]".
  Qed.
  Global Instance own_full_encoded_history_as_fractional γ1 γ2 ℓ q enc_abs_hist :
    AsFractional
      (own_full_encoded_history_loc γ1 γ2 ℓ q enc_abs_hist)
      (λ q, own_full_encoded_history_loc γ1 γ2 ℓ q enc_abs_hist)%I q.
  Proof. split; [done | apply _]. Qed.

  Lemma own_full_history_loc_agree γ1 γ2 ℓ q p abs_hist1 abs_hist2 :
    own_full_history_loc γ1 γ2 ℓ q abs_hist1 -∗
    own_full_history_loc γ1 γ2 ℓ p abs_hist2 -∗
    ⌜ abs_hist1 = abs_hist2 ⌝.
  Proof.
    iIntros "[A _]".
    iIntros "[B _]".
    iDestruct (ghost_map_elem_agree with "A B") as %<-%(inj _).
    done.
  Qed.

  Lemma own_full_history_loc_to_frag γ1 γ2 ℓ q abs_hist :
    own_full_history_loc γ1 γ2 ℓ q abs_hist -∗
    own_frag_history_loc γ2 ℓ abs_hist.
  Proof.
    iIntros "[_ H]". iExists _. iFrame "H".
    iPureIntro.
    apply map_eq. intros t.
    rewrite 3!lookup_fmap.
    destruct (abs_hist !! t); last done.
    simpl. rewrite decode_encode. done.
  Qed.

  Lemma own_frag_history_loc_lookup γ2 ℓ abs_hist t h :
    abs_hist !! t = Some h →
    own_frag_history_loc γ2 ℓ abs_hist -∗
    own_frag_history_loc γ2 ℓ {[ t := h ]}.
  Proof.
    iIntros (look).
    iIntros "(%m & %eq & H)".
    setoid_rewrite map_eq_iff in eq.
    specialize (eq t).
    rewrite 2!lookup_fmap in eq.
    rewrite look in eq.
    simpl in eq.
    rewrite -lookup_fmap in eq.
    apply lookup_fmap_Some in eq as (e & dec & mLook).
    iExists ({[ t := e ]}).
    iDestruct (auth_map_map_frag_lookup_singleton with "H") as "$".
    { rewrite lookup_singleton. done. }
    { done. }
    iPureIntro.
    rewrite !map_fmap_singleton.
    congruence.
  Qed.

  Lemma own_full_history_alloc h :
    ⊢ |==> ∃ γ1 γ2,
        own_full_history γ1 γ2 h ∗
        auth_map_map_frag γ2 h ∗
        [∗ map] k↦v ∈ h, k ↪[γ1] v.
  Proof.
    iMod (ghost_map_alloc h) as (new_abs_history_name) "[A B]".
    iExists _. iFrame "A B".
    setoid_rewrite <- own_op.
    iMod (own_alloc _) as "$".
    { apply auth_both_valid_2; last reflexivity.
      intros k.
      rewrite lookup_fmap.
      case (h !! k); simpl; last done.
      intros ? k'.
      apply Some_valid.
      rewrite lookup_fmap.
      case (g !! k'); done. }
    done.
  Qed.

  Lemma own_full_equiv γ1 γ2 ℓ q abs_hist :
    own_full_history_loc γ1 γ2 ℓ q abs_hist ⊣⊢
      own_full_encoded_history_loc γ1 γ2 ℓ q (encode <$> abs_hist).
  Proof. done. Qed.

  Lemma own_frag_equiv γ ℓ abs_hist :
    own_frag_encoded_history_loc γ ℓ (encode <$> abs_hist) ⊢
    own_frag_history_loc γ ℓ abs_hist.
  Proof.
    rewrite /own_frag_history_loc /own_frag_encoded_history_loc.
    iIntros "H".
    iExists _. iFrame. iPureIntro.
    apply map_eq. intros t.
    rewrite !lookup_fmap.
    destruct (abs_hist !! t); last done.
    simpl. by rewrite decode_encode.
  Qed.

  Lemma abs_hist_to_ra_inj hist hist' :
    abs_hist_to_ra hist' ≡ abs_hist_to_ra hist →
    hist' = hist.
  Proof.
    intros eq.
    apply: map_eq. intros t.
    pose proof (eq t) as eq'.
    rewrite !lookup_fmap in eq'.
    destruct (hist' !! t) as [h|] eqn:leq, (hist !! t) as [h'|] eqn:leq';
      try inversion eq'; auto.
    simpl in eq'.
    apply Some_equiv_inj in eq'.
    apply to_agree_inj in eq'.
    apply encode_inj in eq'.
    rewrite eq'.
    done.
  Qed.

  Lemma abs_hist_to_ra_agree hist hist' :
    to_agree <$> hist' ≡ abs_hist_to_ra hist → hist' = encode <$> hist.
  Proof.
    intros eq.
    apply: map_eq. intros t.
    pose proof (eq t) as eq'.
    rewrite !lookup_fmap in eq'.
    rewrite lookup_fmap.
    destruct (hist' !! t) as [h|] eqn:leq, (hist !! t) as [h'|] eqn:leq';
      try inversion eq'; auto.
    simpl in eq'. simpl.
    apply Some_equiv_inj in eq'.
    apply to_agree_inj in eq'.
    f_equiv.
    apply eq'.
  Qed.

  (** If you know the full history for a location and own the "all-knowing"
  resource, then those two will agree. *)
  Lemma own_full_history_agree γ1 γ2 ℓ q hist hists :
    own_full_history γ1 γ2 hists -∗
    own_full_history_loc γ1 γ2 ℓ q hist -∗
    ⌜hists !! ℓ = Some (encode <$> hist)⌝.
  Proof.
    iIntros "[A _] [B _]".
    iApply (ghost_map_lookup with "[$] [$]").
  Qed.

  Lemma own_frag_history_agree γ1 γ2 ℓ (part_hist : gmap time ST) hists :
    own_full_history γ1 γ2 hists -∗
    own_frag_history_loc γ2 ℓ part_hist -∗
    ⌜∃ hist, hists !! ℓ = Some (hist) ∧
            (Some <$> part_hist) ⊆ (decode <$> hist)⌝.
  Proof.
    rewrite /own_full_history.
    iIntros "[O A]".
    iDestruct 1 as (enc) "[%eq K]".
    iDestruct (own_valid_2 with "A K") as %[incl _]%auth_both_valid_discrete.
    apply fmap_fmap_to_agree_singleton_included_l in incl.
    destruct incl as [hist' [look incl]].
    iPureIntro.
    exists hist'.
    split. { apply leibniz_equiv. done. }
    rewrite -eq. apply map_fmap_mono. done.
  Qed.

  Lemma own_full_history_frag_singleton_agreee γ1 γ2 ℓ t (s : ST) hists :
    own_full_history γ1 γ2 hists -∗
    own_frag_history_loc γ2 ℓ {[ t := s ]} -∗
    ⌜∃ hist enc,
      hists !! ℓ = Some hist ∧ hist !! t = Some enc ∧ decode enc = Some s⌝.
  Proof.
    iIntros "H1 H2".
    iDestruct (own_frag_history_agree with "H1 H2") as %[hist [look H1]].
    iExists hist. iPureIntro.
    rewrite map_fmap_singleton in H1.
    rewrite -> map_subseteq_spec in H1.
    specialize H1 with t (Some s).
    epose proof (H1 _) as H2.
    Unshelve. 2: { rewrite lookup_singleton. done. }
    apply lookup_fmap_Some in H2.
    destruct H2 as (enc & eq & lookHist).
    exists enc.
    repeat split; done.
  Qed.

  Lemma own_full_history_lookup γ1 γ2 abs_hists enc_abs_hist ℓ t s :
    abs_hists !! ℓ = Some enc_abs_hist →
    enc_abs_hist !! t = Some s →
    own_full_history γ1 γ2 abs_hists ==∗
    own_full_history γ1 γ2 abs_hists ∗
    own_frag_encoded_history_loc γ2 ℓ {[ t := s ]}.
  Proof.
    iIntros (look1 look2).
    iIntros "[M N]".
    iMod (auth_map_map_lookup with "N") as "[N hip]"; try done.
    iFrame.
    done.
  Qed.

  Lemma own_frag_history_singleton_agreee γ2 ℓ t s1 s2 :
    own_frag_history_loc γ2 ℓ {[ t := s1 ]} -∗
    own_frag_history_loc γ2 ℓ {[ t := s2 ]} -∗
    ⌜ s1 = s2 ⌝.
  Proof.
    rewrite /own_frag_history_loc.
    rewrite !map_fmap_singleton.
    iDestruct 1 as (enc (e & deq & encEq)%map_fmap_singleton_inv) "K".
    iDestruct 1 as (enc' (e' & deq' & encEq')%map_fmap_singleton_inv) "K'".
    rewrite encEq.
    rewrite encEq'.
    iDestruct (own_valid_2 with "K K'") as %val%auth_frag_op_valid_1.
    iPureIntro. move: val.
    rewrite 2!fmap_fmap_to_agree_singleton.
    rewrite 2!map_fmap_singleton.
    rewrite singleton_op.
    rewrite singleton_valid.
    rewrite singleton_op.
    rewrite singleton_valid.
    intros eq%to_agree_op_inv_L.
    congruence.
  Qed.

  Lemma own_full_history_alloc_frag γ1 γ2 ℓ t encS (s : ST) hists hist :
    hists !! ℓ = Some hist →
    hist !! t = Some encS →
    decode encS = Some s →
    own_full_history γ1 γ2 hists ==∗
    own_full_history γ1 γ2 hists ∗ own_frag_history_loc γ2 ℓ {[ t := s ]}.
  Proof.
    iIntros (look lookHist decEq) "M".
    iMod (own_full_history_lookup with "M") as "[M hi]"; try done.
    iFrame. iModIntro.
    rewrite /own_frag_history_loc.
    iExists {[ t := encS ]}.
    rewrite /own_frag_encoded_history_loc.
    rewrite !map_fmap_singleton.
    rewrite decEq.
    iFrame.
    done.
  Qed.

  (* Insert a new location into an abstract history. *)
  Lemma own_full_history_history_insert_loc γ1 γ2 abs_hists ℓ enc_abs_hist :
    abs_hists !! ℓ = None →
    own_full_history γ1 γ2 abs_hists ==∗
    own_full_history γ1 γ2 (<[ℓ := enc_abs_hist]>abs_hists) ∗
    own_full_encoded_history_loc γ1 γ2 ℓ 1 enc_abs_hist.
    (* own_frag_encoded_history_loc γ2 ℓ enc_abs_hist. *)
  Proof.
    iIntros (look) "[A B]".
    iMod (ghost_map_insert with "A") as "[$ $]"; first done.
    iMod (auth_map_map_insert_top with "B") as "[$ F]"; first done.
    rewrite /own_frag_encoded_history_loc.
    rewrite /auth_map_map_frag.
    rewrite fmap_fmap_to_agree_singleton.
    done.
  Qed.

  (* Insert a new message into an abstract history. *)
  Lemma own_full_encoded_history_insert γ1 γ2 ℓ t enc_abs_hist abs_hists encS :
    enc_abs_hist !! t = None →
    own_full_history γ1 γ2 abs_hists -∗
    own_full_encoded_history_loc γ1 γ2 ℓ 1 enc_abs_hist ==∗
    let enc_abs_hist' := <[t := encS]>enc_abs_hist
    in own_full_history γ1 γ2 (<[ℓ := enc_abs_hist']>abs_hists) ∗
       own_full_encoded_history_loc γ1 γ2 ℓ 1 enc_abs_hist' ∗
       own_frag_encoded_history_loc γ2 ℓ {[ t := encS ]}.
  Proof.
    iIntros (look) "[M N] [O P]".
    iDestruct (ghost_map_lookup with "M O") as %hips.
    iMod (ghost_map_update with "M O") as "[$ $]".
    iMod (auth_map_map_insert with "N") as "[$ h]"; try done.
  Qed.

  (* Insert a new message into an abstract history. *)
  Lemma own_full_history_insert γ1 γ2 ℓ t abs_hist abs_hists (s : ST) :
    abs_hist !! t = None →
    own_full_history γ1 γ2 abs_hists -∗
    own_full_history_loc γ1 γ2 ℓ 1 abs_hist ==∗
    let abs_hist' := <[t := s]>abs_hist
    in own_full_history γ1 γ2 (<[ℓ := encode <$> abs_hist']>abs_hists) ∗
       own_full_history_loc γ1 γ2 ℓ 1 abs_hist' ∗
       own_frag_history_loc γ2 ℓ {[ t := s ]}.
  Proof.
    iIntros (look) "??".
    iMod (own_full_encoded_history_insert with "[$] [$]") as "(H1 & H2 & H3)".
    { rewrite lookup_fmap. apply fmap_None. done. }
    iModIntro.
    rewrite /own_full_history_loc /own_frag_history_loc fmap_insert.
    iFrame "H1 H2".
    iExists _. iFrame.
    rewrite !map_fmap_singleton. by rewrite decode_encode.
  Qed.

End abs_history_lemmas.
