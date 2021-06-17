From iris.algebra Require Import gmap numbers.
From iris.bi Require Import derived_laws.
From iris.base_logic Require Import base_logic.
From iris.proofmode Require Import base tactics classes.

From Perennial.base_logic.lib Require Import ncfupd.

From self.algebra Require Import view.
From self.lang Require Import memory.
From self.high Require Import dprop resources.

Program Definition post_fence {Σ} (P : dProp Σ) : dProp Σ :=
  MonPred (λ tv, P (store_view tv,
                    (persist_view tv ⊔ wb_buffer_view tv),
                    wb_buffer_view tv)) _.
  (* MonPred (λ '(s, p, b), P (s, (p ⊔ b), ∅)) _. *)
Next Obligation.
  (* FIXME: Figure out if there is a way to make [solve_proper] handle this,
  perhaps by using [pointwise_relatio]. *)
  intros Σ P. intros [[??]?] [[??]?] [[??]?]. simpl.
  assert (g0 ⊔ g1 ⊑ g3 ⊔ g4). { solve_proper. }
  apply monPred_mono.
  rewrite !subseteq_prod'.
  done.
Qed.

Notation "'<fence>' P" := (post_fence P) (at level 20, right associativity) : bi_scope.

Class IntoFence {Σ} (P: dProp Σ) (Q : dProp Σ) :=
  into_crash : P -∗ <fence> Q.

Section post_fence.
  Context `{Σ : iprop.gFunctors}.

  Implicit Types (P : dProp Σ).

  Lemma post_fence_at P tv :
    ((<fence> P) tv = P (store_view tv, (persist_view tv ⊔ wb_buffer_view tv), wb_buffer_view tv))%I.
  Proof. done. Qed.

  Lemma post_fence_at_alt P SV PV BV :
    ((<fence> P) (SV, PV, BV) = P (SV, PV ⊔ BV, BV))%I.
  Proof. done. Qed.

  Lemma post_fence_sep P Q : <fence> P ∗ <fence> Q ⊣⊢ <fence> (P ∗ Q).
  Proof.
    iStartProof (iProp _). iIntros ([[sv pv] bv]).
    cbn.
    rewrite monPred_at_sep.
    iSplit; iIntros "$".
  Qed.

End post_fence.

Program Definition floor_buffer {Σ} (P : dProp Σ) : dProp Σ :=
  MonPred (λ tv, P (store_view tv, persist_view tv, ∅)) _.
Next Obligation.
  (* FIXME: Figure out if there is a way to make [solve_proper] handle this,
  perhaps by using [pointwise_relation]. *)
  intros Σ P. intros [[??]?] [[??]?] [[??]?]. simpl.
  apply monPred_mono.
  rewrite !subseteq_prod'.
  done.
Qed.

Notation "'<floorbuf>' P" := (floor_buffer P) (at level 20, right associativity) : bi_scope.

Section floor_buffer.
End floor_buffer.
