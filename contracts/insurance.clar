;; Insurance Contract
;; Provides coverage for lenders against borrower defaults

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u401))
(define-constant ERR_INVALID_AMOUNT (err u402))
(define-constant ERR_POLICY_NOT_FOUND (err u403))
(define-constant ERR_CLAIM_NOT_FOUND (err u404))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u405))
(define-constant ERR_INVALID_CLAIM (err u406))

;; Data Variables
(define-data-var contract-admin principal CONTRACT_OWNER)
(define-data-var insurance-pool-balance uint u0)
(define-data-var policy-counter uint u0)
(define-data-var claim-counter uint u0)
(define-data-var base-premium-rate uint u50) ;; 0.5% base premium
(define-data-var coverage-ratio uint u8000) ;; 80% coverage

;; Data Maps
(define-map insurance-policies
  { policy-id: uint }
  {
    lender: principal,
    loan-id: uint,
    coverage-amount: uint,
    premium-paid: uint,
    premium-rate: uint,
    start-block: uint,
    end-block: uint,
    is-active: bool
  }
)

(define-map insurance-claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    claim-amount: uint,
    default-amount: uint,
    filed-at: uint,
    processed-at: uint,
    status: (string-ascii 20), ;; "pending", "approved", "rejected", "paid"
    payout-amount: uint
  }
)

(define-map lender-policies
  { lender: principal, loan-id: uint }
  { policy-id: uint }
)

(define-map pool-contributors
  { contributor: principal }
  {
    total-contributed: uint,
    share-percentage: uint,
    last-contribution: uint,
    rewards-earned: uint
  }
)

(define-map risk-assessments
  { borrower: principal }
  {
    risk-score: uint,
    premium-multiplier: uint,
    last-assessment: uint
  }
)

;; Read-only functions
(define-read-only (get-policy-info (policy-id uint))
  (map-get? insurance-policies { policy-id: policy-id })
)

(define-read-only (get-claim-info (claim-id uint))
  (map-get? insurance-claims { claim-id: claim-id })
)

(define-read-only (get-lender-policy (lender principal) (loan-id uint))
  (map-get? lender-policies { lender: lender, loan-id: loan-id })
)

(define-read-only (get-pool-contributor (contributor principal))
  (map-get? pool-contributors { contributor: contributor })
)

(define-read-only (get-insurance-pool-balance)
  (var-get insurance-pool-balance)
)

(define-read-only (calculate-premium (coverage-amount uint) (borrower principal) (loan-duration uint))
  (let ((base-rate (var-get base-premium-rate))
        (risk-multiplier (match (map-get? risk-assessments { borrower: borrower })
                           assessment (get premium-multiplier assessment)
                           u100))) ;; Default 1.0x multiplier
    (let ((duration-factor (/ loan-duration u52560)) ;; Blocks per year approximation
          (risk-adjusted-rate (/ (* base-rate risk-multiplier) u100)))
      (/ (* coverage-amount risk-adjusted-rate duration-factor) u10000)
    )
  )
)

(define-read-only (calculate-coverage-amount (loan-amount uint))
  (/ (* loan-amount (var-get coverage-ratio)) u10000)
)

(define-read-only (get-pool-utilization)
  ;; Simplified implementation - in practice would calculate actual utilization
  (let ((pool-balance (var-get insurance-pool-balance)))
    (if (is-eq pool-balance u0)
      u0
      u5000 ;; Return 50% as placeholder utilization
    )
  )
)

;; Admin functions
(define-public (set-insurance-parameters (base-premium uint) (coverage-ratio-new uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (var-set base-premium-rate base-premium)
    (var-set coverage-ratio coverage-ratio-new)
    (ok true)
  )
)

(define-public (update-risk-assessment (borrower principal) (risk-score uint) (premium-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (map-set risk-assessments
      { borrower: borrower }
      {
        risk-score: risk-score,
        premium-multiplier: premium-multiplier,
        last-assessment: block-height
      }
    )
    (ok true)
  )
)

;; Public functions
(define-public (contribute-to-pool (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    ;; Update pool balance
    (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) amount))

    ;; Update contributor record
    (let ((current-contribution (default-to { total-contributed: u0, share-percentage: u0, last-contribution: u0, rewards-earned: u0 }
                                  (get-pool-contributor tx-sender))))
      (map-set pool-contributors
        { contributor: tx-sender }
        (merge current-contribution {
          total-contributed: (+ (get total-contributed current-contribution) amount),
          last-contribution: block-height
        })
      )
    )

    ;; Recalculate share percentages (simplified)
    ;; In practice, this would be more complex to handle all contributors

    ;; Transfer tokens would happen here
    (ok true)
  )
)

(define-public (purchase-coverage (loan-id uint) (loan-amount uint) (borrower principal) (loan-duration uint))
  (begin
    (let ((coverage-amount (calculate-coverage-amount loan-amount))
          (premium-amount (calculate-premium coverage-amount borrower loan-duration))
          (new-policy-id (+ (var-get policy-counter) u1)))

      (asserts! (>= (var-get insurance-pool-balance) coverage-amount) ERR_INSUFFICIENT_FUNDS)

      ;; Create insurance policy
      (map-set insurance-policies
        { policy-id: new-policy-id }
        {
          lender: tx-sender,
          loan-id: loan-id,
          coverage-amount: coverage-amount,
          premium-paid: premium-amount,
          premium-rate: (calculate-premium u10000 borrower loan-duration),
          start-block: block-height,
          end-block: (+ block-height loan-duration),
          is-active: true
        }
      )

      ;; Map lender to policy
      (map-set lender-policies
        { lender: tx-sender, loan-id: loan-id }
        { policy-id: new-policy-id }
      )

      ;; Add premium to pool
      (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) premium-amount))

      (var-set policy-counter new-policy-id)

      ;; Transfer premium would happen here
      (ok new-policy-id)
    )
  )
)

(define-public (file-claim (policy-id uint) (default-amount uint))
  (begin
    (match (get-policy-info policy-id)
      policy
      (begin
        (asserts! (is-eq (get lender policy) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (get is-active policy) ERR_POLICY_NOT_FOUND)

        (let ((new-claim-id (+ (var-get claim-counter) u1))
              (claim-amount (if (<= default-amount (get coverage-amount policy))
                default-amount
                (get coverage-amount policy))))

          ;; Create claim record
          (map-set insurance-claims
            { claim-id: new-claim-id }
            {
              policy-id: policy-id,
              claimant: tx-sender,
              claim-amount: claim-amount,
              default-amount: default-amount,
              filed-at: block-height,
              processed-at: u0,
              status: "pending",
              payout-amount: u0
            }
          )

          (var-set claim-counter new-claim-id)
          (ok new-claim-id)
        )
      )
      ERR_POLICY_NOT_FOUND
    )
  )
)

(define-public (process-claim (claim-id uint) (approve bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (match (get-claim-info claim-id)
      claim
      (begin
        (asserts! (is-eq (get status claim) "pending") ERR_CLAIM_ALREADY_PROCESSED)

        (if approve
          (let ((payout-amount (get claim-amount claim)))
            (asserts! (>= (var-get insurance-pool-balance) payout-amount) ERR_INSUFFICIENT_FUNDS)

            ;; Update claim status
            (map-set insurance-claims
              { claim-id: claim-id }
              (merge claim {
                status: "approved",
                processed-at: block-height,
                payout-amount: payout-amount
              })
            )

            ;; Reduce pool balance
            (var-set insurance-pool-balance (- (var-get insurance-pool-balance) payout-amount))

            ;; Deactivate policy
            (match (get-policy-info (get policy-id claim))
              policy
              (map-set insurance-policies
                { policy-id: (get policy-id claim) }
                (merge policy { is-active: false })
              )
              true
            )

            ;; Transfer payout would happen here
            (ok payout-amount)
          )
          ;; Reject claim
          (begin
            (map-set insurance-claims
              { claim-id: claim-id }
              (merge claim {
                status: "rejected",
                processed-at: block-height
              })
            )
            (ok u0)
          )
        )
      )
      ERR_CLAIM_NOT_FOUND
    )
  )
)

(define-public (withdraw-pool-contribution (amount uint))
  (begin
    (match (get-pool-contributor tx-sender)
      contributor
      (begin
        (asserts! (>= (get total-contributed contributor) amount) ERR_INSUFFICIENT_FUNDS)
        (asserts! (>= (var-get insurance-pool-balance) amount) ERR_INSUFFICIENT_FUNDS)

        ;; Check if withdrawal doesn't compromise pool solvency
        (let ((utilization (get-pool-utilization)))
          (asserts! (<= utilization u7000) ERR_INSUFFICIENT_FUNDS) ;; Max 70% utilization

          ;; Update contributor record
          (map-set pool-contributors
            { contributor: tx-sender }
            (merge contributor {
              total-contributed: (- (get total-contributed contributor) amount)
            })
          )

          ;; Update pool balance
          (var-set insurance-pool-balance (- (var-get insurance-pool-balance) amount))

          ;; Transfer tokens would happen here
          (ok true)
        )
      )
      ERR_UNAUTHORIZED
    )
  )
)

(define-public (cancel-policy (policy-id uint))
  (begin
    (match (get-policy-info policy-id)
      policy
      (begin
        (asserts! (is-eq (get lender policy) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (get is-active policy) ERR_POLICY_NOT_FOUND)

        ;; Deactivate policy
        (map-set insurance-policies
          { policy-id: policy-id }
          (merge policy { is-active: false })
        )

        ;; Calculate refund (simplified - would be prorated)
        (let ((refund-amount (/ (get premium-paid policy) u2))) ;; 50% refund example
          ;; Transfer refund would happen here
          (ok refund-amount)
        )
      )
      ERR_POLICY_NOT_FOUND
    )
  )
)

(define-public (distribute-rewards)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    ;; This would distribute rewards to pool contributors based on their share
    ;; Simplified implementation
    (ok true)
  )
)
