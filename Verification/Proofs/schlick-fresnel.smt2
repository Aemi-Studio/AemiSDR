; id: schlick-fresnel
; claim: the Schlick transmission 1 - (F0 + (1 - F0)(1 - cos)^5) stays in [0, 1 - F0] so its clamp never changes it, is non-decreasing in cos, and equals 1 - F0 at normal incidence
; source: Sources/AemiSDR/Shaders/LiquidLens.metal#fresnelSchlickTransmission sha256:5decc29ce79e9bc3dd5787deb2e36de98d632955612f739d345de005d8ef7d68
; expect: unsat unsat unsat unsat unsat unsat sat
;
; x = 1 - cos is unrolled to x*x*x*x*x exactly as the shader does. Real-number model: the shader runs this in half
; precision, whose rounding is outside this proof.
(declare-const f0 Real)(declare-const c Real)(declare-const c2 Real)
(define-fun unit ((v Real)) Bool (and (<= 0.0 v) (<= v 1.0)))
(define-fun fr ((k Real) (cs Real)) Real (let ((x (- 1.0 cs))) (+ k (* (- 1.0 k) (* x x x x x)))))
(define-fun tr ((k Real) (cs Real)) Real (- 1.0 (fr k cs)))
(define-fun clamp01 ((v Real)) Real (ite (< v 0.0) 0.0 (ite (> v 1.0) 1.0 v)))
; 1. reflectance is at least F0
(push)(assert (and (unit f0) (unit c) (< (fr f0 c) f0)))(check-sat)(pop)
; 2. reflectance is at most 1
(push)(assert (and (unit f0) (unit c) (> (fr f0 c) 1.0)))(check-sat)(pop)
; 3. transmission is within [0, 1 - F0]
(push)(assert (and (unit f0) (unit c) (or (< (tr f0 c) 0.0) (> (tr f0 c) (- 1.0 f0)))))(check-sat)(pop)
; 4. so the shader's clamp(1 - F, 0, 1) never changes the value
(push)(assert (and (unit f0) (unit c) (not (= (clamp01 (tr f0 c)) (tr f0 c)))))(check-sat)(pop)
; 5. more light is transmitted at steeper incidence: non-decreasing in cos
(push)(assert (and (unit f0) (unit c) (unit c2) (< c c2) (> (tr f0 c) (tr f0 c2))))(check-sat)(pop)
; 6. at normal incidence (cos = 1) transmission is exactly 1 - F0
(push)(assert (and (unit f0) (not (= (tr f0 1.0) (- 1.0 f0)))))(check-sat)(pop)
; CONTROL (must be sat): grazing incidence really does transmit less than normal incidence
(push)(assert (and (< f0 1.0) (unit f0) (< (tr f0 0.5) (tr f0 1.0))))(check-sat)(pop)
