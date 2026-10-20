; id: rounded-rect-sdf
; claim: the rounded-rectangle signed distance has the right sign, is -min(a,b) at the centre, and the masks built on it fully cover every pixel outside the shape and the outermost pixel row (the corner wedges, out to the pointy corners)
; source: Sources/AemiSDR/Shaders/LiquidLens.metal#sdRoundedRect sha256:bd31081b775445acceb79ada05691b1a66fcc7e8c689f16d5d1c41221caafbb2
; source: Sources/AemiSDR/Shaders/AemiSDR.ci.metal#rounded_rect_sdf sha256:5bf235d49ef04dc20ad83dbb58a4d842ff44605e802cb088fc2172a0fdbc7a4f
; source: Sources/AemiSDR/Shaders/AemiSDR.ci.metal#distance_to_alpha sha256:ac4dd5bd27f5ae92f7de75accf46bc7ac4031e2bdf144637efac8afb59ef1177
; source: Sources/AemiSDR/Shaders/AemiSDR.ci.metal#roundedRectAlphaMask sha256:c448d820d46c011799d0c7a70ea43ad36fada09c413434581fad19953c0fa5ad
; source: Sources/AemiSDR/Shaders/AemiSDR.ci.metal#roundedRectEaseAlphaMask sha256:d77225b800a840a572fc5f5d2ae424a2916f5caeaeb037decfe3722a6bfa0efe
; expect: unsat unsat unsat unsat unsat unsat unsat unsat unsat sat sat sat sat
;
; Model: (a,b) are the half sizes, R the requested radius, r = clamp(R, 0, min(a,b)) exactly as the shader does,
; L the length of max(d,0) (L >= 0, L*L = sum of squares), and a mask samples the distance plus the half-pixel
; bias kPixelCenterBias = 0.5. Real-number model.
(declare-const px Real)(declare-const py Real)(declare-const a Real)(declare-const b Real)
(declare-const R Real)(declare-const L Real)(declare-const w Real)
(define-fun absr ((v Real)) Real (ite (>= v 0.0) v (- v)))
(define-fun posp ((v Real)) Real (ite (> v 0.0) v 0.0))
(define-fun negp ((v Real)) Real (ite (< v 0.0) v 0.0))
(define-fun maxr ((u Real) (v Real)) Real (ite (>= u v) u v))
(define-fun m () Real (ite (<= a b) a b))
(define-fun r () Real (ite (< R 0.0) 0.0 (ite (> R m) m R)))
(define-fun dx () Real (- (absr px) (- a r)))
(define-fun dy () Real (- (absr py) (- b r)))
(define-fun sdf () Real (- (+ L (negp (maxr dx dy))) r))
(define-fun clamp01 ((v Real)) Real (ite (< v 0.0) 0.0 (ite (> v 1.0) 1.0 v)))
(define-fun alphaSmooth ((d Real) (fw Real)) Real
  (ite (<= fw 0.0) (ite (>= d 0.0) 1.0 0.0)
       (let ((s (clamp01 (/ (+ d fw) fw)))) (* s s (- 3.0 (* 2.0 s))))))
(define-fun alphaEase ((d Real) (fw Real)) Real
  (ite (<= fw 0.0) (ite (>= d 0.0) 1.0 0.0)
       (let ((s (clamp01 (+ 1.0 (/ d fw))))) (* s s))))
(define-fun inside () Bool
  (or (and (< (absr px) a) (< (absr py) (- b r)))
      (and (< (absr px) (- a r)) (< (absr py) b))
      (< (+ (* dx dx) (* dy dy)) (* r r))))
(assert (> a 0.0))(assert (> b 0.0))(assert (>= w 0.0))
(assert (>= L 0.0))(assert (= (* L L) (+ (* (posp dx) (posp dx)) (* (posp dy) (posp dy)))))
; 1. negative distance implies strictly inside
(push)(assert (and (< sdf 0.0) (not inside)))(check-sat)(pop)
; 2. strictly inside implies negative distance
(push)(assert (and inside (>= sdf 0.0)))(check-sat)(pop)
; 3. at the centre the distance is -min(a,b)
(push)(assert (and (= px 0.0) (= py 0.0) (not (= sdf (- m)))))(check-sat)(pop)
; 4. THE CORNER WEDGES: every point not strictly inside the shape, including the wedge out to the pointy
;    corner, is fully masked by both the smoothstep kernel and the eased kernel
(push)(assert (and (not inside) (not (= (alphaSmooth (+ sdf 0.5) w) 1.0))))(check-sat)(pop)
(push)(assert (and (not inside) (not (= (alphaEase (+ sdf 0.5) w) 1.0))))(check-sat)(pop)
; 5. THE OUTERMOST PIXEL ROW: a pixel centre half a pixel inside the extent (|px| >= a - 0.5, or the same
;    for y) is fully masked, for every radius and fade width, in both kernels
(push)(assert (and (>= (- (absr px) a) (- 0.5)) (not (= (alphaSmooth (+ sdf 0.5) w) 1.0))))(check-sat)(pop)
(push)(assert (and (>= (- (absr px) a) (- 0.5)) (not (= (alphaEase (+ sdf 0.5) w) 1.0))))(check-sat)(pop)
(push)(assert (and (>= (- (absr py) b) (- 0.5)) (not (= (alphaSmooth (+ sdf 0.5) w) 1.0))))(check-sat)(pop)
(push)(assert (and (>= (- (absr py) b) (- 0.5)) (not (= (alphaEase (+ sdf 0.5) w) 1.0))))(check-sat)(pop)
; CONTROLS (must be sat): the distance takes both signs, the inside is not fully masked, and WITHOUT the
; half-pixel bias the outermost row of a pointy shape is NOT fully covered (the defect the bias fixed)
(push)(assert (< sdf 0.0))(check-sat)(pop)
(push)(assert (> sdf 0.0))(check-sat)(pop)
(push)(assert (and inside (> w 0.0) (< (alphaSmooth (+ sdf 0.5) w) 1.0)))(check-sat)(pop)
(push)(assert (and (= R 0.0) (= w 2.0) (= (absr px) (- a 0.5)) (< (absr py) (- b 1.0)) (< (alphaSmooth sdf w) 1.0)))(check-sat)(pop)
