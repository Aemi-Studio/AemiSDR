; id: falloff-curves
; claim: each of the six falloff polynomials maps [0,1] into [0,1], is non-decreasing, and fixes 0 and 1
; source: Sources/AemiSDR/Shaders/LiquidLens.metal#applyFalloff sha256:a2fc22058f58ddcffed1e3147bb5fbc3c7bcbde2d3073883dd5205200f4b8ce8
; expect: unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat unsat sat sat
;
; applyFalloff clamps t to [0,1] first, so the domain of every polynomial here is [0,1]. Real-number model: this
; says nothing about float32 rounding, which the GPU tests bound separately.
(declare-const t Real)
(declare-const u Real)
(define-fun unit ((x Real)) Bool (and (<= 0.0 x) (<= x 1.0)))
(define-fun f0 ((x Real)) Real x) ; linear
(define-fun f1 ((x Real)) Real (* x x)) ; ease-in
(define-fun f2 ((x Real)) Real (- 1.0 (* (- 1.0 x) (- 1.0 x)))) ; ease-out
(define-fun f3 ((x Real)) Real (* x x (- 3.0 (* 2.0 x)))) ; smoothstep
(define-fun f4 ((x Real)) Real (* x x x)) ; cubic
(define-fun f5 ((x Real)) Real (* x x x x)) ; quartic
; linear: stays in [0,1]
(push)(assert (and (unit t) (or (< (f0 t) 0.0) (> (f0 t) 1.0))))(check-sat)(pop)
; linear: non-decreasing
(push)(assert (and (unit t) (unit u) (< t u) (> (f0 t) (f0 u))))(check-sat)(pop)
; linear: fixes the endpoints
(push)(assert (not (and (= (f0 0.0) 0.0) (= (f0 1.0) 1.0))))(check-sat)(pop)
; ease-in: stays in [0,1]
(push)(assert (and (unit t) (or (< (f1 t) 0.0) (> (f1 t) 1.0))))(check-sat)(pop)
; ease-in: non-decreasing
(push)(assert (and (unit t) (unit u) (< t u) (> (f1 t) (f1 u))))(check-sat)(pop)
; ease-in: fixes the endpoints
(push)(assert (not (and (= (f1 0.0) 0.0) (= (f1 1.0) 1.0))))(check-sat)(pop)
; ease-out: stays in [0,1]
(push)(assert (and (unit t) (or (< (f2 t) 0.0) (> (f2 t) 1.0))))(check-sat)(pop)
; ease-out: non-decreasing
(push)(assert (and (unit t) (unit u) (< t u) (> (f2 t) (f2 u))))(check-sat)(pop)
; ease-out: fixes the endpoints
(push)(assert (not (and (= (f2 0.0) 0.0) (= (f2 1.0) 1.0))))(check-sat)(pop)
; smoothstep: stays in [0,1]
(push)(assert (and (unit t) (or (< (f3 t) 0.0) (> (f3 t) 1.0))))(check-sat)(pop)
; smoothstep: non-decreasing
(push)(assert (and (unit t) (unit u) (< t u) (> (f3 t) (f3 u))))(check-sat)(pop)
; smoothstep: fixes the endpoints
(push)(assert (not (and (= (f3 0.0) 0.0) (= (f3 1.0) 1.0))))(check-sat)(pop)
; cubic: stays in [0,1]
(push)(assert (and (unit t) (or (< (f4 t) 0.0) (> (f4 t) 1.0))))(check-sat)(pop)
; cubic: non-decreasing
(push)(assert (and (unit t) (unit u) (< t u) (> (f4 t) (f4 u))))(check-sat)(pop)
; cubic: fixes the endpoints
(push)(assert (not (and (= (f4 0.0) 0.0) (= (f4 1.0) 1.0))))(check-sat)(pop)
; quartic: stays in [0,1]
(push)(assert (and (unit t) (or (< (f5 t) 0.0) (> (f5 t) 1.0))))(check-sat)(pop)
; quartic: non-decreasing
(push)(assert (and (unit t) (unit u) (< t u) (> (f5 t) (f5 u))))(check-sat)(pop)
; quartic: fixes the endpoints
(push)(assert (not (and (= (f5 0.0) 0.0) (= (f5 1.0) 1.0))))(check-sat)(pop)
; CONTROL (must be sat, so the run is not vacuous): the ease-in curve really dips below the identity
(push)(assert (and (< 0.0 t) (< t 1.0) (< (f1 t) t)))(check-sat)(pop)
; CONTROL: the ease-out curve really rises above the identity
(push)(assert (and (< 0.0 t) (< t 1.0) (> (f2 t) t)))(check-sat)(pop)
