;;;;  json-streams
;;;;
;;;;  Copyright (C) 2013 Thomas Bakketun <thomas.bakketun@copyleft.no>
;;;;
;;;;  This library is free software: you can redistribute it and/or modify
;;;;  it under the terms of the GNU Lesser General Public License as published
;;;;  by the Free Software Foundation, either version 3 of the License, or
;;;;  (at your option) any later version.
;;;;
;;;;  This library is distributed in the hope that it will be useful,
;;;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;;  GNU General Public License for more details.
;;;;
;;;;  You should have received a copy of the GNU General Public License
;;;;  along with this library.  If not, see <http://www.gnu.org/licenses/>.

(in-package #:json-streams)

;;; From
;;; Printing Floating-Point Numbers Quickly and Accurately
;;; by Robert G. Burger and R. Kent Dybvig

(defun flonum->digits (v f e min-e p b BB)
  (let ((roundp (evenp f)))
    (if (>= e 0)
        (if (not (= f (expt b (- p 1))))
            (let ((be (expt b e)))
              (scale (* f be 2) 2 be be 0 BB roundp roundp v))
            (let* ((be (expt b e))
                   (be1 (* be b)))
              (scale (* f be1 2) (* b 2) be1 be 0 BB roundp roundp v)))
        (if (or (= e min-e) (not (= f (expt b (- p 1)))))
            (scale (* f 2) (* (expt b (- e)) 2) 1 1 0 BB roundp roundp v)
            (scale (* f b 2) (* (expt b (- 1 e)) 2) b 1 0 BB roundp roundp v)))))

(defun generate (r s m+ m- BB low-ok-p high-ok-p)
  (multiple-value-bind (d r)
      (truncate (* r BB) s)
    (let ((m+ (* m+ BB))
          (m- (* m- BB)))
      (let ((tc1 (funcall (if low-ok-p #'<= #'<) r m-))
            (tc2 (funcall (if high-ok-p #'>= #'>) (+ r m+) s)))
        (if (not tc1)
            (if (not tc2)
                (cons d (generate r s m+ m- BB low-ok-p high-ok-p))
                (list (+ d 1)))
            (if (not tc2)
                (list d)
                (if (< (* r 2) s)
                    (list d)
                    (list (+ d 1)))))))))

(defun scale (r s m+ m- k BB low-ok-p high-ok-p v)
  (declare (ignore k))
  (let ((est (ceiling (- (logB BB v) 1d-10))))
    (if (>= est 0)
        (fixup r (* s (exptt BB est)) m+ m- est BB low-ok-p high-ok-p)
        (let ((scale (exptt BB (- est))))
          (fixup (* r scale) s (* m+ scale) (* m- scale) est BB low-ok-p high-ok-p)))))

(defun fixup (r s m+ m- k BB low-ok-p high-ok-p)
  (if (funcall (if high-ok-p #'>= #'>) (+ r m+) s) ; too low?
      (cons (+ k 1) (generate r (* s BB) m+ m- BB low-ok-p high-ok-p))
      (cons k (generate r s m+ m- BB low-ok-p high-ok-p))))

(let ((table (make-array 326)))
  (do ((k 0 (+ k 1)) (v 1 (* v 10)))
      ((= k 326))
    (setf (svref table k) v))
  (defun exptt (BB k)
    (if (and (= BB 10) (<= 0 k 325))
        (svref table k)
        (expt BB k))))

(let ((table (make-array 37)))
  (do ((BB 2 (+ BB 1)))
      ((= BB 37))
    (setf (svref table BB) (/ (log BB))))
  (defun logB (BB x)
    (if (<= 2 BB 36)
        (* (log x) (svref table BB))
        (/ (log x) (log BB)))))

(defconstant +min-e+ (1+ (nth-value 1 (integer-decode-float least-positive-normalized-double-float))))
(defconstant +precision+ (float-digits 0d0))
(defconstant +float-radix+ 2)
(defconstant +output-base+ 10)

(defun write-float (float stream)
  (multiple-value-bind (f e s)
      (integer-decode-float float)
    (destructuring-bind (exp &rest digits)
        (flonum->digits (abs float) f e +min-e+ +precision+ +float-radix+ +output-base+)
      (when (minusp s)
        (princ "-" stream))
      (if (and (< (length digits) 16)
               (<= -2 exp 8))
          (if (plusp exp)
              (format stream "~{~D~}.~{~D~}" (subseq digits 0 exp) (subseq digits exp))
              (format stream "0.~v@{0~}~{~D~}" (abs exp) digits))
          (format stream "~D.~:[0~;~:*~{~D~}~]E~D" (first digits) (rest digits) (1- exp))))))
