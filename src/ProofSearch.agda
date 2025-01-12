{-# OPTIONS --guardedness #-}

open import Level                                 using (_⊔_)
open import Algebra                               using (module CommutativeSemiring; module DistributiveLattice)
open import Function                              using (id; const; _∘_; _$_)
open import Agda.Builtin.Coinduction              using (∞; ♯_; ♭)
open import Data.Fin        as Fin                using (Fin; suc; zero)
open import Data.List       as List               using (List; _∷_; _∷ʳ_; []; [_]; _++_; length; concat; foldr; concatMap; zipWith; reverse; downFrom)
open import Data.Maybe                            using (Maybe; just; nothing)
open import Data.Nat                              using (ℕ; suc; zero; _≤_; z≤n; s≤s)
open import Data.Nat.Properties                   using (+-*-commutativeSemiring; ⊓-⊔-distributiveLattice; ≤-decTotalOrder)
open import Data.Product    as Prod               using (∃; _×_; _,_; proj₁)
open import Data.Sum                              using (_⊎_; inj₁; inj₂)
open import Data.Vec        as Vec                using (Vec; _∷_; []; fromList)
open import Data.Bool                             using (Bool; true; false)
open import Relation.Nullary                      using (Dec; yes; no)
open import Relation.Binary                       using (module DecTotalOrder)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; sym; trans; cong; subst)



module ProofSearch
  (RuleName : Set)
  (TermName : Set) (_≟-TermName_ : (x y : TermName) → Dec (x ≡ y))
  (Literal  : Set) (_≟-Literal_  : (x y : Literal)  → Dec (x ≡ y))
  where

  open import Unification TermName _≟-TermName_ Literal _≟-Literal_ public hiding (_++_)


  ----------------------------------------------------------------------------
  -- * define rules and utility functions                                 * --
  ----------------------------------------------------------------------------

  private
    ∃-syntax : ∀ {a b} {A : Set a} → (A → Set b) → Set (b ⊔ a)
    ∃-syntax = ∃
    syntax ∃-syntax (λ x → B) = ∃[ x ] B

  -- introduce rules
  record Rule (n : ℕ) : Set where
    constructor rule
    field
      name        : RuleName
      conclusion  : Term n
      premises    : List (Term n)

  open Rule using (name; conclusion; premises)


  -- alias for list of rules
  Rules : Set
  Rules = List (∃ Rule)


  -- compute the arity of a rule
  arity : ∀ {n} (r : Rule n) → ℕ
  arity = length ∘ premises


  -- open instances relevant to definitions of difference, inject and raise
  open CommutativeSemiring +-*-commutativeSemiring using (_+_; +-comm)
  open DistributiveLattice ⊓-⊔-distributiveLattice using (_∧_; ∧-comm)
  open DecTotalOrder       ≤-decTotalOrder         using (total)


  -- compute the difference between two natural numbers, given an
  -- ordering between them.
  Δ_ : ∀ {m n} → m ≤ n → ℕ
  Δ z≤n {k} = k
  Δ s≤s  p  = Δ p

  -- correctness proof of the difference operator Δ.
  Δ-correct : ∀ {m n} (p : m ≤ n) → n ≡ m + Δ p
  Δ-correct  z≤n    = refl
  Δ-correct (s≤s p) = cong suc (Δ-correct p)

  -- type class for injections in the fashion of Fin.inject+
  record Inject (T : ℕ → Set) : Set where
    field
      inject : ∀ {m} n → T m → T (m + n)

    inject≤ : ∀ {m n} → m ≤ n → T m → T n
    inject≤ {m} {n} p t = subst T (sym (Δ-correct p)) (inject (Δ p) t)

  open Inject {{...}} using (inject; inject≤)


  -- type class for raising in the fashion of Fin.raise
  record Raise (T : ℕ → Set) : Set where
    field
      raise : ∀ {m} n → T m → T (n + m)

    raise≤ : ∀ {m n} → m ≤ n → T m → T n
    raise≤ {m} {n} p t = subst T (sym (trans (Δ-correct p) (+-comm m (Δ p)))) (raise (Δ p) t)

  open Raise {{...}} using (raise; raise≤)


  -- instances for inject/raise for all used data types
  instance
    InjectFin   : Inject Fin
    InjectFin   = record { inject = Fin.inject+ }
    RaiseFin    : Raise  Fin
    RaiseFin    = record { raise  = Fin.raise }
    InjectTerm  : Inject Term
    InjectTerm  = record { inject = λ n → replace (var ∘ inject n) }
    RaiseTerm   : Raise  Term
    RaiseTerm   = record { raise  = λ m → replace (var ∘ raise m) }
    InjectTerms : Inject (List ∘ Term)
    InjectTerms = record { inject = λ n → List.map (inject n) }
    RaiseTerms  : Raise  (List ∘ Term)
    RaiseTerms  = record { raise  = λ m → List.map (raise m) }
    InjectGoals : ∀ {k} → Inject (λ n → Vec (Term n) k)
    InjectGoals = record { inject = λ n → Vec.map (inject n) }
    RaiseGoals  : ∀ {k} → Raise (λ n → Vec (Term n) k)
    RaiseGoals  = record { raise  = λ m → Vec.map (raise m) }
    InjectRule  : Inject Rule
    InjectRule  = record { inject = λ n → λ { (rule nm c p) → rule nm (inject n c) (inject n p) } }
    RaiseRule   : Raise Rule
    RaiseRule   = record { raise  = λ m → λ { (rule nm c p) → rule nm (raise m c) (raise m p) } }

  -- could rephrase inject/raise in terms of allowing modification by
  -- a function ℕ → ℕ, but really... why would I... it makes all the
  -- other instances much, much more obtuse
  injectSubst : ∀ {m n} (δ : ℕ) → Subst m n → Subst (m + δ) (n + δ)
  injectSubst _ nil = nil
  injectSubst δ (snoc s t x) = snoc (injectSubst δ s) (inject δ t) (inject δ x)


  private
    m≤n→m⊔n=n : ∀ {m n} → m ≤ n → m ∧ n ≡ n
    m≤n→m⊔n=n  z≤n    = refl
    m≤n→m⊔n=n (s≤s p) = cong suc (m≤n→m⊔n=n p)


  -- match indices of injectable data types
  match : ∀ {m n} {I J} {{i : Inject I}} {{j : Inject J}}
        → I m → J n → I (m ∧ n) × J (m ∧ n)
  match {m} {n} i j with total m n
  ... | inj₁ p rewrite              m≤n→m⊔n=n p = (inject≤ p i , j)
  ... | inj₂ p rewrite ∧-comm m n | m≤n→m⊔n=n p = (i , inject≤ p j)


  ----------------------------------------------------------------------------
  -- * define hint databases                                              * --
  ----------------------------------------------------------------------------

  record IsHintDB : Set₁ where
    field
      HintDB   : Set
      Hint     : ℕ → Set

    Hints : Set
    Hints = List (∃ Hint)

    field
      getHints   : HintDB → Hints
      getRule    : ∀ {k} → Hint k → Rule k
      getTr      : ∀ {k} → Hint k → (HintDB → HintDB)
      ε          : HintDB
      _∙_        : HintDB → HintDB → HintDB
      return     : ∀ {k} → Rule k → HintDB

    fromRules : Rules → HintDB
    fromRules []             = ε
    fromRules ((k , r) ∷ rs) = return r ∙ fromRules rs


  ----------------------------------------------------------------------------
  -- * define simple hint databases                                       * --
  ----------------------------------------------------------------------------

  simpleHintDB : IsHintDB
  simpleHintDB = record
    { HintDB   = Rules
    ; Hint     = Rule
    ; getHints = id
    ; getRule  = id
    ; getTr    = const id
    ; ε        = []
    ; _∙_      = _++_
    ; return   = λ r → [ _ , r ]
    }


  ----------------------------------------------------------------------------
  -- * define search trees, proofs and partial proofs                     * --
  ----------------------------------------------------------------------------

  -- simple alias to set apart the goal term
  Goal = Term

  -- search trees
  data SearchTree (A : Set) (B : Set) : Set where
    succ-leaf : B → A → SearchTree A B
    fail-leaf : B → SearchTree A B
    node  : B → List (∞ (SearchTree A B)) → SearchTree A B

  -- representation of a failed branch
  -- fail : ∀ {A} → SearchTree A
  -- fail = node []

  data Proof : Set where
     con : (name : RuleName) (args : List Proof) → Proof

  -- representation of an incomplete proof
  Proof′ : ℕ → Set
  Proof′ m = ∃[ k ] (Vec (Goal m) k × (Vec Proof k → Proof))

  con′ : ∀ {n k} (r : Rule n) → Vec Proof (arity r + k) → Vec Proof (suc k)
  con′ {n} {k} r xs = head ∷ rest
    where
      head : Proof
      head = con (name r) (Vec.toList $ Vec.take (arity r) xs)
      rest : Vec Proof k
      rest = Vec.drop (arity r) xs


  DebugInfo = Maybe RuleName

  ----------------------------------------------------------------------------
  -- * define proof search function                                       * --
  ----------------------------------------------------------------------------

  module Extensible (isHintDB : IsHintDB) where

    open IsHintDB isHintDB

    solve : ∀ {m} → Goal m → HintDB → SearchTree Proof DebugInfo
    solve {m} g = solveAcc {m} nothing (1 , g ∷ [] , Vec.head)
      where
        solveAcc : ∀ {m} → Maybe RuleName → Proof′ m → HintDB → SearchTree Proof DebugInfo
        solveAcc {m} nm (0     ,     [] , p) _  = succ-leaf nm (p [])
        solveAcc {m} nm (suc k , g ∷ gs , p) db = node nm (steps (getHints db))
          where
            step : ∃[ δ ] (Hint δ) → ∞ (SearchTree Proof DebugInfo)
            step (δ , h) with unify (inject δ g) (raise m (conclusion (getRule h)))
            ... | nothing        = ♯ fail-leaf (just (name (getRule h)))
            ... | just (n , mgu) = ♯ solveAcc {n} (just (name (getRule h)))  prf (getTr h db)
              where
                prf : Proof′ n
                prf = arity (getRule h) + k , gs′ , (p ∘ con′ (getRule h))
                  where
                    prm′ = raise m (Vec.fromList (premises (getRule h)))
                    gs′  = Vec.map (replace (sub mgu)) (prm′ Vec.++ inject δ gs)


            -- equivalent to `map step` due to termination checker
            steps : List (∃ Hint) → List (∞ (SearchTree Proof DebugInfo))
            steps []       = []
            steps (h ∷ hs) = step h ∷ steps hs

  ----------------------------------------------------------------------------
  -- * define various search strategies                                   * --
  ----------------------------------------------------------------------------

  -- debug information collected by the proof search
  record Debug (B : Set) : Set where
    constructor debug
    field
      index  : List ℕ
      depth  : ℕ
      fail?  : Bool
      info   : B

  Strategy : Set₁
  Strategy = ∀ {A B} (depth : ℕ) → SearchTree A B → List A × List (Debug B)


  dfs' : ∀ {A B} (depth : ℕ) → (ℕ × List ℕ) → SearchTree A B → List A × List (Debug B)
  dfs' zero _ _ = ([] , [])
  dfs' (suc k) (n , p) (fail-leaf l)     = []     , [ debug (suc n ∷ p) (suc k) true  l ]
  dfs' (suc k) (n , p) (succ-leaf l x)   = [ x ]  , [ debug (suc n ∷ p) (suc k) false l ]
  dfs' (suc k) (n , p) (node l xs )
    with foldr {B = ℕ × List (List _) × List (List _)}
        (λ {x ( m , ( ys , zs )) →  let (y , z) = dfs' k (m , suc n ∷ p) (♭ x)
                                    in  (suc m , (ys ∷ʳ y , zs ∷ʳ z))})
        (0 , ([] , [])) xs
  ...| _ , a , b = (concat a , (debug (suc n ∷ p) (suc k) false l) ∷ concat b)

  dfs : Strategy
  dfs d s = dfs' d (0 , []) s


  bfs : Strategy
  bfs depth t = foldr (λ { (x , y) (xs , ys) → (x ++ xs , y ++ ys)}) ([] , []) (Vec.toList (bfsAcc depth (0 , []) t))
    where
      merge : ∀ {A B : Set} {k} → (xs ys : Vec (List A × List B) k) → Vec (List A × List B) k
      merge [] [] = []
      merge ((x₁ , x₂) ∷ xs) ((y₁ , y₂) ∷ ys) = ((x₁ ++ y₁) , (x₂ ++ y₂)) ∷ merge xs ys

      empty : ∀ {A B : Set} {k} → Vec (List A × List B) k
      empty {k = zero}  = []
      empty {k = suc k} = ([] , []) ∷ empty

      bfsAcc : ∀ {A B} (depth : ℕ) → (ℕ × List ℕ) → SearchTree A B → Vec (List A × List (Debug B)) depth
      bfsAcc  zero _  _        = []
      bfsAcc (suc k) (n , p) (fail-leaf l  )  = ([]    , [ debug (suc n ∷ p) (suc k) true  l ]) ∷ empty
      bfsAcc (suc k) (n , p) (succ-leaf l x)  = ([ x ] , [ debug (suc n ∷ p) (suc k) false l ]) ∷ empty
      bfsAcc (suc k) (n , p) (node l xs) =
        ([] , [ debug (suc n ∷ p) (suc k) false l ])
        ∷ proj₁ (foldr (λ {x (vs , m) → (merge vs (bfsAcc k (m , suc n ∷ p) (♭ x)) , suc m)})
                (empty , 0) xs)
