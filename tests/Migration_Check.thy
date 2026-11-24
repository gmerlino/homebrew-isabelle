theory Migration_Check
  imports Main
begin

lemma hol_check: "rev (rev xs) = (xs :: nat list)"
  by simp

lemma hammer_check:
  assumes "\<forall>x. P x \<longrightarrow> Q x" "\<forall>x. Q x \<longrightarrow> R x" "P a"
  shows "R a"
  sledgehammer [provers = e, timeout = 30, expect = some]
  using assms by blast

lemma smt_verit_check:
  fixes x y z :: int
  assumes "x < y" "y \<le> z"
  shows "x + 1 \<le> z"
  using assms by (smt (verit))

lemma smt_cvc5_check:
  fixes x y z :: int
  assumes "x < y" "y \<le> z"
  shows "x + 1 \<le> z"
  using assms by (smt (cvc5))

lemma vampire_check:
  assumes "\<forall>x. P x \<longrightarrow> Q x" "\<forall>x. Q x \<longrightarrow> R x" "P a"
  shows "R a"
  sledgehammer [provers = vampire, timeout = 30, expect = some]
  using assms by blast

lemma smt_z3_check:
  fixes x y z :: int
  assumes "x < y" "y \<le> z"
  shows "x + 1 \<le> z"
  using assms by (smt (z3))

end
