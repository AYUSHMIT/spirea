From stdpp Require Export binders strings.
From stdpp Require Import gmap.
From iris.algebra Require Export ofe.
From iris.program_logic Require Export language ectx_language ectxi_language.
From iris.prelude Require Import options.

From self.lang Require Export memory.

(* nvm_lang.  A language with release/acquire weak memory and persistent
non-volatile memory. The language is adapted from HeapLang. *)

(* Scope delimiters like the ones that HeapLang has. *)
Delimit Scope expr_scope with E.
Delimit Scope val_scope with V.

Module nvm_lang.

  Implicit Type ℓ : loc.

  (* Literals of the language. *)
  Inductive lit : Set :=
    | LitInt (n : Z) | LitBool (b : bool) | LitUnit | LitLoc ℓ.

  Inductive expr :=
    (* Embed values inside expressions. *)
    | Val (v : val)
    (* Functions and application. *)
    | Var (x : string)
    | Rec (f x : binder) (e : expr)
    | App (e1 e2 : expr)
    (* Concurrency *)
    | Fork (e : expr)
    (* Memory operations. *)
    | Read (e : expr)
    | ReadAcquire (e : expr)
    | Store (e1 e2 : expr)
    | StoreRelease (e1 e2 : expr)
    (* RMW memory operations. *)
    | CmpXchg (e0 : expr) (e1 : expr) (e2 : expr) (* Compare-exchange *)
    | FAA (e1 : expr) (e2 : expr) (* Fetch-and-add *)
    with val :=
    | LitV (l : lit)
    | RecV (f x : binder) (e : expr)
    | PairV (v1 v2 : val)
    | InjLV (v : val)
    | InjRV (v : val).

  Bind Scope expr_scope with expr.
  Bind Scope val_scope with val.

  Notation of_val := Val (only parsing).

  Definition to_val (e : expr) : option val :=
    match e with
    | Val v => Some v
    | _ => None
    end.

  (* Evaluation contexts. *)
  Inductive ectx_item :=
  .

  (* [fill_item] inserts an expression into an evaluation context. On paper this
  is often denoted K[e]. *)
  Fixpoint fill_item (Ki : ectx_item) (e : expr) : expr :=
    e.

  (** Substitution *)
  (* Replace occurrences of [x] in [e] with [v]. *)
  Fixpoint subst (x : string) (v : val) (e : expr)  : expr := e.


  (* Per thread expression reductions. Note: This does not fit the format that
  Iris expects---we mold it later on. *)
  Inductive head_step : expr → option mem_event → expr → list expr → Prop :=

  Inductive head_step : expr → state → list observation → expr → state → list expr → Prop :=

End nvm_lang.