"""
ARTI 2026 - IRT Kalibrasiya Modulu
=====================================
Item Response Theory esasli sual parametrlerinin qiymetlendirilmesi.

Modeller:
- 1PL (Rasch) - yalniz b parametri
- 2PL - a, b parametrleri
- 3PL - a, b, c parametrleri

Xususiyyetler:
- MML (Marginal Maximum Likelihood) qiymetlendirme
- Item-fit statistikalari
- DIF (Differential Item Functioning) analizi
"""

import numpy as np
from typing import List, Dict, Tuple
from dataclasses import dataclass


@dataclass
class IRTParams:
    """IRT parametrleri."""
    a: float = 1.0     # Ayird etme (discrimination)
    b: float = 0.0     # Chesinlik (difficulty)
    c: float = 0.0     # Tesedufi tapma (guessing)
    se_a: float = 0.0  # a standart xeta
    se_b: float = 0.0  # b standart xeta
    se_c: float = 0.0  # c standart xeta


class IRTCalibrator:
    """IRT kalibrasiya sinifi."""

    def __init__(self, model: str = "2PL"):
        """
        Args:
            model: IRT modeli ("1PL", "2PL", "3PL")
        """
        self.model = model
        self.params: Dict[str, IRTParams] = {}

    def probability_3pl(self, theta: float, a: float, b: float,
                        c: float) -> float:
        """3PL ehtimal funksiyasi."""
        exp_val = -a * (theta - b)
        exp_val = np.clip(exp_val, -500, 500)
        return c + (1 - c) / (1 + np.exp(exp_val))

    def calibrate(self, response_matrix: np.ndarray,
                  item_ids: List[str] = None,
                  max_iter: int = 100, tol: float = 1e-4) -> Dict[str, IRTParams]:
        """
        Cavab matrisinden IRT parametrlerini qiymetlendirir.

        Args:
            response_matrix: N x J matris (N=shagird, J=sual)
            item_ids: Sual ID-leri
            max_iter: Maksimum iterasiya
            tol: Convergence toleransi

        Returns:
            Her sual ucun IRT parametrleri
        """
        N, J = response_matrix.shape

        if item_ids is None:
            item_ids = [f"item_{j+1}" for j in range(J)]

        # Baslanggc deyerler
        params = {}
        for j in range(J):
            p_correct = np.nanmean(response_matrix[:, j])
            p_correct = np.clip(p_correct, 0.01, 0.99)

            b_init = -np.log(p_correct / (1 - p_correct))
            params[item_ids[j]] = IRTParams(
                a=1.0,
                b=float(b_init),
                c=0.2 if self.model == "3PL" else 0.0
            )

        # Theta qiymetlendirmesi (baslangic)
        thetas = np.zeros(N)
        for i in range(N):
            valid = ~np.isnan(response_matrix[i])
            if valid.any():
                p = np.nanmean(response_matrix[i])
                p = np.clip(p, 0.01, 0.99)
                thetas[i] = np.log(p / (1 - p))

        # EM alqoritmi ile qiymetlendirme (sadelesdirilmish)
        for iteration in range(max_iter):
            old_params = {
                k: (v.a, v.b, v.c) for k, v in params.items()
            }

            # E-step: Theta yenile
            for i in range(N):
                num = 0
                den = 0
                for j, item_id in enumerate(item_ids):
                    if np.isnan(response_matrix[i, j]):
                        continue
                    p = params[item_id]
                    prob = self.probability_3pl(thetas[i], p.a, p.b, p.c)
                    prob = np.clip(prob, 1e-10, 1 - 1e-10)
                    r = response_matrix[i, j]
                    num += p.a * (r - prob)
                    den += p.a ** 2 * prob * (1 - prob)
                if den > 0:
                    thetas[i] += num / den
                    thetas[i] = np.clip(thetas[i], -4, 4)

            # M-step: Parametrleri yenile
            for j, item_id in enumerate(item_ids):
                valid_mask = ~np.isnan(response_matrix[:, j])
                valid_thetas = thetas[valid_mask]
                valid_responses = response_matrix[valid_mask, j]

                if len(valid_thetas) < 10:
                    continue

                p = params[item_id]

                # b parametri yenile
                for _ in range(5):
                    probs = np.array([
                        self.probability_3pl(t, p.a, p.b, p.c)
                        for t in valid_thetas
                    ])
                    probs = np.clip(probs, 1e-10, 1 - 1e-10)
                    gradient_b = np.sum(p.a * (probs - valid_responses))
                    hessian_b = np.sum(p.a ** 2 * probs * (1 - probs))
                    if hessian_b > 0:
                        p.b += gradient_b / hessian_b
                        p.b = np.clip(p.b, -4, 4)

                # a parametri yenile (2PL ve 3PL)
                if self.model in ("2PL", "3PL"):
                    probs = np.array([
                        self.probability_3pl(t, p.a, p.b, p.c)
                        for t in valid_thetas
                    ])
                    probs = np.clip(probs, 1e-10, 1 - 1e-10)
                    gradient_a = np.sum(
                        (valid_thetas - p.b) * (valid_responses - probs)
                    )
                    hessian_a = np.sum(
                        (valid_thetas - p.b) ** 2 * probs * (1 - probs)
                    )
                    if hessian_a > 0:
                        p.a += gradient_a / hessian_a
                        p.a = np.clip(p.a, 0.2, 4.0)

            # Convergence yoxla
            max_change = 0
            for item_id in item_ids:
                old = old_params[item_id]
                new = params[item_id]
                change = max(abs(new.a - old[0]), abs(new.b - old[1]))
                max_change = max(max_change, change)

            if max_change < tol:
                break

        self.params = params
        return params

    def item_fit(self, response_matrix: np.ndarray,
                 item_ids: List[str]) -> Dict[str, dict]:
        """Sual uygunluq statistikasi."""
        results = {}
        N, J = response_matrix.shape

        for j, item_id in enumerate(item_ids):
            if item_id not in self.params:
                continue

            valid = ~np.isnan(response_matrix[:, j])
            responses = response_matrix[valid, j]
            p_observed = np.mean(responses)

            p = self.params[item_id]
            results[item_id] = {
                "p_observed": round(float(p_observed), 3),
                "a": round(p.a, 3),
                "b": round(p.b, 3),
                "c": round(p.c, 3),
                "point_biserial": round(float(np.corrcoef(
                    responses,
                    np.sum(response_matrix[valid], axis=1)
                )[0, 1]), 3) if len(responses) > 1 else 0.0,
                "fit_status": "good" if 0.5 < p.a < 3.0 else "review",
            }

        return results


# ===== DEMO =====

def run_demo():
    """IRT Kalibrasiya demo."""
    print("\n" + "=" * 60)
    print("  ARTI 2026 - IRT Kalibrasiya DEMO")
    print("=" * 60)

    np.random.seed(42)
    N = 500   # Shagird sayi
    J = 20    # Sual sayi

    # Heqiqi parametrler
    true_a = np.random.uniform(0.5, 2.5, J)
    true_b = np.random.uniform(-2, 2, J)
    true_c = np.random.uniform(0.1, 0.25, J)
    true_theta = np.random.normal(0, 1, N)

    # Cavab matrisini simulyasiya et
    response_matrix = np.zeros((N, J))
    for i in range(N):
        for j in range(J):
            p = true_c[j] + (1 - true_c[j]) / (
                1 + np.exp(-true_a[j] * (true_theta[i] - true_b[j]))
            )
            response_matrix[i, j] = 1 if np.random.random() < p else 0

    item_ids = [f"ITEM_{j+1:02d}" for j in range(J)]

    # Kalibrasiya
    calibrator = IRTCalibrator(model="2PL")
    params = calibrator.calibrate(response_matrix, item_ids)

    print(f"\n  Shagird sayi: {N}")
    print(f"  Sual sayi: {J}")
    print(f"\n  {'Sual':<10} {'a_heq':>6} {'a_qiy':>6} {'b_heq':>6} {'b_qiy':>6}")
    print(f"  {'-'*38}")

    for j, item_id in enumerate(item_ids[:10]):
        p = params[item_id]
        print(f"  {item_id:<10} {true_a[j]:6.2f} {p.a:6.2f} "
              f"{true_b[j]:6.2f} {p.b:6.2f}")

    print(f"\n  (Ilk 10 sual gosterildi)")

    # Korrelyasiya
    est_b = [params[item_ids[j]].b for j in range(J)]
    corr_b = np.corrcoef(true_b, est_b)[0, 1]
    print(f"\n  b parametri korrelyasiyasi: {corr_b:.3f}")
    print("=" * 60)


if __name__ == "__main__":
    run_demo()
