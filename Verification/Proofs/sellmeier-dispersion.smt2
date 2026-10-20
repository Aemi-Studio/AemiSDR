; id: sellmeier-dispersion
; claim: every term of the Sellmeier index decreases with wavelength on either side of its resonance, no material has a resonance inside the visible band (380-780 nm), each material's typed-in coefficients give n(blue) > n(green) > n(red) > n_air and the published index at 546.1 nm
; source: Sources/AemiSDR/Effects/LiquidLens/LiquidLensConfiguration.swift#sellmeierCoefficients sha256:836f11e7c5ff810777ed8cd845606516f7d05b1331d8571a93bf311c19024d4a
; source: Sources/AemiSDR/Effects/LiquidLens/LiquidLensConfiguration.swift#sellmeierIndex sha256:ff141f8e7f900e6fff0daabbfd00ee8eea09807ddcc9105edcf222699536c562
; expect: unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat sat
;
; n^2(l) = 1 + sum_i B_i l^2 / (l^2 - C_i), with l in micrometres, C_i = resonance wavelength squared.
; Normal dispersion over the visible band follows from: (lemma) each term is decreasing in l^2 on each side of its
; pole, plus (data) every B_i >= 0 and every C_i lies outside [0.38^2, 0.78^2] = [0.1444, 0.6084], so no pole
; is crossed. The sum of decreasing terms is decreasing. The coefficients below are copied from the code and a test
; checks that each number appears in the source. Exact rational arithmetic; no floating point is involved.
(declare-const x1 Real)(declare-const x2 Real)(declare-const C Real)
; LEMMA A: above the pole, x/(x-C) is decreasing in x
(push)(assert (and (>= C 0.0) (> x1 C) (< x1 x2) (< (/ x1 (- x1 C)) (/ x2 (- x2 C)))))(check-sat)(pop)
; LEMMA B: below the pole, x/(x-C) is decreasing in x
(push)(assert (and (>= C 0.0) (> x1 0.0) (> C x2) (< x1 x2) (< (/ x1 (- x1 C)) (/ x2 (- x2 C)))))(check-sat)(pop)
(define-fun lb () Real (* 0.4861 0.4861))
(define-fun lg () Real (* 0.5461 0.5461))
(define-fun lr () Real (* 0.6563 0.6563))
(define-fun nair () Real 1.000293)
(define-fun outside ((c Real)) Bool (or (< c 0.1444) (> c 0.6084)))

; ---- crown: Schott N-BK7, n_e = 1.51872
(define-fun n2_crown ((l2 Real)) Real (+ 1.0 (* 1.03961212 (/ l2 (- l2 0.00600069867))) (* 0.231792344 (/ l2 (- l2 0.0200179144))) (* 1.01046945 (/ l2 (- l2 103.560653)))))
(push)(assert (not (and (> (n2_crown lb) (n2_crown lg)) (> (n2_crown lg) (n2_crown lr)))))(check-sat)(pop)  ; blue > green > red
(push)(assert (<= (n2_crown lr) (* nair nair)))(check-sat)(pop)  ; n(red) > n_air, so eta < 1
(push)(assert (not (and (> (n2_crown lg) (* 1.5186 1.5186)) (< (n2_crown lg) (* 1.5188 1.5188)))))(check-sat)(pop)  ; published index at 546.1 nm
(push)(assert (not (and (>= 1.03961212 0.0) (outside 0.00600069867) (>= 0.231792344 0.0) (outside 0.0200179144) (>= 1.01046945 0.0) (outside 103.560653))))(check-sat)(pop)  ; B >= 0 and no pole in the visible band

; ---- flint: Schott N-SF11
(define-fun n2_flint ((l2 Real)) Real (+ 1.0 (* 1.73759695 (/ l2 (- l2 0.013188707))) (* 0.313747346 (/ l2 (- l2 0.0623068142))) (* 1.89878101 (/ l2 (- l2 155.23629)))))
(push)(assert (not (and (> (n2_flint lb) (n2_flint lg)) (> (n2_flint lg) (n2_flint lr)))))(check-sat)(pop)  ; blue > green > red
(push)(assert (<= (n2_flint lr) (* nair nair)))(check-sat)(pop)  ; n(red) > n_air, so eta < 1
(push)(assert (not (and (> (n2_flint lg) (* 1.7918 1.7918)) (< (n2_flint lg) (* 1.7921 1.7921)))))(check-sat)(pop)  ; published index at 546.1 nm
(push)(assert (not (and (>= 1.73759695 0.0) (outside 0.013188707) (>= 0.313747346 0.0) (outside 0.0623068142) (>= 1.89878101 0.0) (outside 155.23629))))(check-sat)(pop)  ; B >= 0 and no pole in the visible band

; ---- water: Daimon and Masumura 2007, 20 C, n = 1.3348
(define-fun n2_water ((l2 Real)) Real (+ 1.0 (* 0.5684027565 (/ l2 (- l2 0.005101829712))) (* 0.1726177391 (/ l2 (- l2 0.01821153936))) (* 0.02086189578 (/ l2 (- l2 0.02620722293))) (* 0.1130748688 (/ l2 (- l2 10.69792721)))))
(push)(assert (not (and (> (n2_water lb) (n2_water lg)) (> (n2_water lg) (n2_water lr)))))(check-sat)(pop)  ; blue > green > red
(push)(assert (<= (n2_water lr) (* nair nair)))(check-sat)(pop)  ; n(red) > n_air, so eta < 1
(push)(assert (not (and (> (n2_water lg) (* 1.3347 1.3347)) (< (n2_water lg) (* 1.3350 1.3350)))))(check-sat)(pop)  ; published index at 546.1 nm
(push)(assert (not (and (>= 0.5684027565 0.0) (outside 0.005101829712) (>= 0.1726177391 0.0) (outside 0.01821153936) (>= 0.02086189578 0.0) (outside 0.02620722293) (>= 0.1130748688 0.0) (outside 10.69792721))))(check-sat)(pop)  ; B >= 0 and no pole in the visible band

; ---- acrylic: Sultanova 2009 (PMMA)
(define-fun n2_acrylic ((l2 Real)) Real (+ 1.0 (* 0.99654 (/ l2 (- l2 0.00787))) (* 0.18964 (/ l2 (- l2 0.02191))) (* 0.00411 (/ l2 (- l2 3.85727)))))
(push)(assert (not (and (> (n2_acrylic lb) (n2_acrylic lg)) (> (n2_acrylic lg) (n2_acrylic lr)))))(check-sat)(pop)  ; blue > green > red
(push)(assert (<= (n2_acrylic lr) (* nair nair)))(check-sat)(pop)  ; n(red) > n_air, so eta < 1
(push)(assert (not (and (> (n2_acrylic lg) (* 1.4925 1.4925)) (< (n2_acrylic lg) (* 1.4927 1.4927)))))(check-sat)(pop)  ; published index at 546.1 nm
(push)(assert (not (and (>= 0.99654 0.0) (outside 0.00787) (>= 0.18964 0.0) (outside 0.02191) (>= 0.00411 0.0) (outside 3.85727))))(check-sat)(pop)  ; B >= 0 and no pole in the visible band

; ---- diamond: Peter 1923, n_e = 2.4236
(define-fun n2_diamond ((l2 Real)) Real (+ 1.0 (* 0.3306 (/ l2 (- l2 0.030625))) (* 4.3356 (/ l2 (- l2 0.011236)))))
(push)(assert (not (and (> (n2_diamond lb) (n2_diamond lg)) (> (n2_diamond lg) (n2_diamond lr)))))(check-sat)(pop)  ; blue > green > red
(push)(assert (<= (n2_diamond lr) (* nair nair)))(check-sat)(pop)  ; n(red) > n_air, so eta < 1
(push)(assert (not (and (> (n2_diamond lg) (* 2.4235 2.4235)) (< (n2_diamond lg) (* 2.4237 2.4237)))))(check-sat)(pop)  ; published index at 546.1 nm
(push)(assert (not (and (>= 0.3306 0.0) (outside 0.030625) (>= 4.3356 0.0) (outside 0.011236))))(check-sat)(pop)  ; B >= 0 and no pole in the visible band

; CONTROL (must be sat): if a pole DOES lie between x1 and x2 the term can increase, so the band condition is necessary
(push)(assert (and (>= C 0.0) (< x1 C) (< C x2) (< (/ x1 (- x1 C)) (/ x2 (- x2 C)))))(check-sat)(pop)
