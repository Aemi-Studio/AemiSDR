; id: snell-refraction
; claim: for light passing from air into any denser medium (eta = n1/n2 < 1) total internal reflection cannot occur, so the guard in snellDeviation never rejects an incidence angle, and the refracted direction is a unit vector
; source: Sources/AemiSDR/Effects/LiquidLens/LiquidLensConfiguration.swift#snellDeviation sha256:d589d61a10e25f395acf32fbc649d0fd88c610fefd60f8e94d6555a5e770f864
; expect: unsat unsat unsat sat
;
; sin_t = eta * sin_i (Snell), cos_t = sqrt(1 - sin_t^2). snellDeviation returns 0 when |sin_t| >= 1.
(declare-const eta Real)(declare-const si Real)(declare-const ct Real)
(define-fun st () Real (* eta si))
(define-fun denser () Bool (and (> eta 0.0) (< eta 1.0) (<= (- 1.0) si) (<= si 1.0)))
; 1. the asin argument stays strictly inside (-1, 1): the guard cannot trigger
(push)(assert (and denser (>= (* st st) 1.0)))(check-sat)(pop)
; 2. bending toward the normal: |sin_t| <= |sin_i|
(push)(assert (and denser (> (* st st) (* si si))))(check-sat)(pop)
; 3. the transmitted direction (sin_t, cos_t) has unit length
(push)(assert (and denser (>= ct 0.0) (= (* ct ct) (- 1.0 (* st st))) (not (= (+ (* st st) (* ct ct)) 1.0))))(check-sat)(pop)
; CONTROL (must be sat): going from the denser medium to the lighter one (eta > 1) CAN be totally reflected
(push)(assert (and (> eta 1.0) (<= (- 1.0) si) (<= si 1.0) (>= (* st st) 1.0)))(check-sat)(pop)
