{-# OPTIONS --guardedness #-}

open import Auto
open import Data.Nat using (ℕ; suc; zero; _+_)
open import Relation.Binary.PropositionalEquality as PropEq using (_≡_; refl; cong; sym)

module Auto.Example.Even where

  private
    n+0≡n : ∀ n → n + 0 ≡ n
    n+0≡n zero    = refl
    n+0≡n (suc n) = cong suc (n+0≡n n)

    m+1+n≡1+m+n : ∀ m n → m + suc n ≡ suc (m + n)
    m+1+n≡1+m+n zero    n = refl
    m+1+n≡1+m+n (suc m) n = cong suc (m+1+n≡1+m+n m n)


  data Even  : ℕ →  Set where
    isEven0  : Even 0
    isEven+2 : ∀ {n} → Even n → Even (suc (suc n))

  even+ : ∀ {n m} → Even n → Even m → Even (n + m)
  even+  isEven0      e2 = e2
  even+ (isEven+2 e1) e2 = isEven+2 (even+ e1 e2)

  isEven-2 : ∀ {n} → Even (2 + n) → Even n
  isEven-2 (isEven+2 n) = n

  simple : ∀ {n} → Even n → Even (n + 2)
  simple e =  even+ e (isEven+2 isEven0)

  rules : HintDB
  rules = ε << isEven0
            << isEven+2
            << even+

  test₁ : Even 4
  test₁ = apply (auto 4 rules)

  -- test2 : ∀ {n} → Even n → Even (n + 2)
  -- test2 e = apply (auto 4 rules)

  -- test₃ : ∀ {n} → Even n → Even (4 + n)
  -- test₃ p = apply (auto 4 rules)

  -- test₄ : ∀ {n} → Even n → Even (n + 16)
  -- test₄ = apply (auto 20 rules)

  -- attempting to prove an impossible goal (e.g. evenness of n + 3
  -- for all n) will result in searchSpaceExhausted
  -- goal₁ = quoteTerm (∀ {n} → Even n → Even (n + 3))
  -- fail₁ : (auto 5 rules goal₁) ≡ throw searchSpaceExhausted
  -- fail₁ = refl

  -- attempting to convert an unsupported expression (e.g. a lambda
  -- term) will result in unsupportedSyntax
  -- goal₂ = quoteTerm (∃₂ λ m n → Even (m + n))
  -- fail₂ : unquote (auto 5 rules goal₂) ≡ throw unsupportedSyntax
  -- fail₂ = refl
