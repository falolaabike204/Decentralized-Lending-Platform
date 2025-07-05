;; User Rating Contract
;; Manages credit scores and reputation for borrowers

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_USER_NOT_FOUND (err u301))
(define-constant ERR_INVALID_RATING (err u302))
(define-constant ERR_INSUFFICIENT_HISTORY (err u303))

;; Data Variables
(define-data-var contract-admin principal CONTRACT_OWNER)
(define-data-var min-credit-score uint u300)
(define-data-var max-credit-score uint u850)
(define-data-var default-credit-score uint u600)

;; Data Maps
(define-map user-ratings
  { user: principal }
  {
    credit-score: uint,
    total-loans: uint,
    successful-repayments: uint,
    defaults: uint,
    total-borrowed: uint,
    total-repaid: uint,
    last-update: uint,
    first-loan: uint
  }
)

(define-map loan-history
  { user: principal, loan-id: uint }
  {
    amount: uint,
    repaid-amount: uint,
    due-date: uint,
    repaid-date: uint,
    status: (string-ascii 20), ;; "active", "repaid", "defaulted", "liquidated"
    days-late: uint
  }
)

(define-map rating-factors
  { factor: (string-ascii 20) }
  { weight: uint, max-impact: uint }
)

;; Initialize rating factors
(map-set rating-factors { factor: "payment-history" } { weight: u35, max-impact: u100 })
(map-set rating-factors { factor: "credit-utilization" } { weight: u30, max-impact: u100 })
(map-set rating-factors { factor: "length-of-history" } { weight: u15, max-impact: u100 })
(map-set rating-factors { factor: "loan-diversity" } { weight: u10, max-impact: u100 })
(map-set rating-factors { factor: "recent-activity" } { weight: u10, max-impact: u100 })

;; Read-only functions
(define-read-only (get-user-rating (user principal))
  (map-get? user-ratings { user: user })
)

(define-read-only (get-loan-history (user principal) (loan-id uint))
  (map-get? loan-history { user: user, loan-id: loan-id })
)

(define-read-only (get-credit-score (user principal))
  (match (get-user-rating user)
    rating (get credit-score rating)
    (var-get default-credit-score)
  )
)

(define-read-only (calculate-payment-history-score (user principal))
  (match (get-user-rating user)
    rating
    (let ((total-loans (get total-loans rating))
          (successful-repayments (get successful-repayments rating))
          (defaults (get defaults rating)))
      (if (is-eq total-loans u0)
        u50 ;; Neutral score for new users
        (let ((success-rate (/ (* successful-repayments u100) total-loans))
              (default-rate (/ (* defaults u100) total-loans)))
          (- u100 (* default-rate u2)) ;; Penalize defaults heavily
        )
      )
    )
    u50
  )
)

(define-read-only (calculate-credit-utilization-score (user principal))
  ;; This would integrate with lending pool to get current utilization
  ;; For now, return a placeholder score
  u75
)

(define-read-only (calculate-history-length-score (user principal))
  (match (get-user-rating user)
    rating
    (let ((first-loan (get first-loan rating))
          (blocks-since-first (- block-height first-loan)))
      (if (is-eq first-loan u0)
        u0
        (let ((calculated-score (/ blocks-since-first u1000)))
          (if (<= calculated-score u100)
            calculated-score
            u100)) ;; Cap at 100
      )
    )
    u0
  )
)

(define-read-only (calculate-risk-premium (user principal))
  (let ((credit-score (get-credit-score user)))
    (if (>= credit-score u750)
      u0 ;; No premium for excellent credit
      (if (>= credit-score u700)
        u25 ;; 0.25% premium
        (if (>= credit-score u650)
          u50 ;; 0.50% premium
          (if (>= credit-score u600)
            u100 ;; 1.00% premium
            (if (>= credit-score u550)
              u200 ;; 2.00% premium
              u300))))) ;; 3.00% premium for poor credit
  )
)

(define-read-only (get-rating-tier (user principal))
  (let ((credit-score (get-credit-score user)))
    (if (>= credit-score u800)
      "excellent"
      (if (>= credit-score u740)
        "very-good"
        (if (>= credit-score u670)
          "good"
          (if (>= credit-score u580)
            "fair"
            "poor"))))
  )
)

;; Admin functions
(define-public (set-rating-parameters (min-score uint) (max-score uint) (default-score uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (var-set min-credit-score min-score)
    (var-set max-credit-score max-score)
    (var-set default-credit-score default-score)
    (ok true)
  )
)

(define-public (update-rating-factor (factor (string-ascii 20)) (weight uint) (max-impact uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (map-set rating-factors
      { factor: factor }
      { weight: weight, max-impact: max-impact }
    )
    (ok true)
  )
)

;; Public functions
(define-public (initialize-user (user principal))
  (begin
    (asserts! (is-none (get-user-rating user)) ERR_USER_NOT_FOUND)
    (map-set user-ratings
      { user: user }
      {
        credit-score: (var-get default-credit-score),
        total-loans: u0,
        successful-repayments: u0,
        defaults: u0,
        total-borrowed: u0,
        total-repaid: u0,
        last-update: block-height,
        first-loan: u0
      }
    )
    (ok true)
  )
)

(define-public (record-new-loan (user principal) (loan-id uint) (amount uint) (due-date uint))
  (begin
    ;; Initialize user if not exists
    (if (is-none (get-user-rating user))
      (unwrap! (initialize-user user) ERR_USER_NOT_FOUND)
      true
    )

    (match (get-user-rating user)
      rating
      (begin
        ;; Update user rating
        (map-set user-ratings
          { user: user }
          (merge rating {
            total-loans: (+ (get total-loans rating) u1),
            total-borrowed: (+ (get total-borrowed rating) amount),
            first-loan: (if (is-eq (get first-loan rating) u0) block-height (get first-loan rating)),
            last-update: block-height
          })
        )

        ;; Record loan history
        (map-set loan-history
          { user: user, loan-id: loan-id }
          {
            amount: amount,
            repaid-amount: u0,
            due-date: due-date,
            repaid-date: u0,
            status: "active",
            days-late: u0
          }
        )

        (ok true)
      )
      ERR_USER_NOT_FOUND
    )
  )
)

(define-public (record-repayment (user principal) (loan-id uint) (repaid-amount uint) (is-full-repayment bool))
  (begin
    (match (get-loan-history user loan-id)
      loan-record
      (begin
        (match (get-user-rating user)
          rating
          (begin
            (let ((new-repaid-amount (+ (get repaid-amount loan-record) repaid-amount))
                  (is-on-time (<= block-height (get due-date loan-record)))
                  (days-late (if is-on-time u0 (- block-height (get due-date loan-record)))))

              ;; Update loan history
              (map-set loan-history
                { user: user, loan-id: loan-id }
                (merge loan-record {
                  repaid-amount: new-repaid-amount,
                  repaid-date: block-height,
                  status: (if is-full-repayment "repaid" "active"),
                  days-late: days-late
                })
              )

              ;; Update user rating if full repayment
              (if is-full-repayment
                (map-set user-ratings
                  { user: user }
                  (merge rating {
                    successful-repayments: (+ (get successful-repayments rating) u1),
                    total-repaid: (+ (get total-repaid rating) repaid-amount),
                    last-update: block-height
                  })
                )
                true
              )

              ;; Recalculate credit score
              (unwrap! (update-credit-score user) ERR_INVALID_RATING)
              (ok true)
            )
          )
          ERR_USER_NOT_FOUND
        )
      )
      ERR_USER_NOT_FOUND
    )
  )
)

(define-public (record-default (user principal) (loan-id uint))
  (begin
    (match (get-loan-history user loan-id)
      loan-record
      (begin
        (match (get-user-rating user)
          rating
          (begin
            ;; Update loan history
            (map-set loan-history
              { user: user, loan-id: loan-id }
              (merge loan-record {
                status: "defaulted",
                repaid-date: block-height
              })
            )

            ;; Update user rating
            (map-set user-ratings
              { user: user }
              (merge rating {
                defaults: (+ (get defaults rating) u1),
                last-update: block-height
              })
            )

            ;; Recalculate credit score
            (unwrap! (update-credit-score user) ERR_INVALID_RATING)
            (ok true)
          )
          ERR_USER_NOT_FOUND
        )
      )
      ERR_USER_NOT_FOUND
    )
  )
)

(define-public (update-credit-score (user principal))
  (begin
    (match (get-user-rating user)
      rating
      (begin
        (let ((payment-score (calculate-payment-history-score user))
              (utilization-score (calculate-credit-utilization-score user))
              (history-score (calculate-history-length-score user)))

          ;; Weighted average of different factors
          (let ((composite-score (+
                                  (/ (* payment-score u35) u100)
                                  (/ (* utilization-score u30) u100)
                                  (/ (* history-score u15) u100)
                                  u20))) ;; Base score for other factors

            (let ((new-credit-score (+ (var-get min-credit-score)
                                     (/ (* composite-score
                                          (- (var-get max-credit-score) (var-get min-credit-score)))
                                        u100))))

              (map-set user-ratings
                { user: user }
                (merge rating {
                  credit-score: new-credit-score,
                  last-update: block-height
                })
              )

              (ok new-credit-score)
            )
          )
        )
      )
      ERR_USER_NOT_FOUND
    )
  )
)

(define-public (bulk-update-scores (users (list 50 principal)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (ok (map update-credit-score users))
  )
)
