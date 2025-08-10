;; REVIEWFORGE PRODUCT REVIEW PLATFORM SMART CONTRACT
;;
;; A comprehensive blockchain-powered product review ecosystem that provides:
;; - Immutable product catalog management with transparent registration
;; - Authentic customer review collection with verified rating systems  
;; - Decentralized review aggregation with real-time statistical analysis
;; - Tamper-proof review storage ensuring permanent data integrity
;; - Scalable paginated review browsing for optimal user experience
;; - Multi-level administrative controls for platform governance
;; - Community-driven content moderation with ownership verification

;; ERROR CODE DEFINITIONS

(define-constant ERR-UNAUTHORIZED-ACCESS u1)
(define-constant ERR-PRODUCT-NOT-FOUND u2)
(define-constant ERR-INSUFFICIENT-PERMISSIONS u3)
(define-constant ERR-INVALID-RATING-SCORE u4)
(define-constant ERR-REVIEW-NOT-FOUND u5)
(define-constant ERR-PRODUCT-ALREADY-REGISTERED u6)
(define-constant ERR-PRODUCT-INACTIVE u7)
(define-constant ERR-OPERATION-FAILED u8)
(define-constant ERR-INVALID-PAGE-NUMBER u9)
(define-constant ERR-INVALID-INPUT-DATA u10)
(define-constant ERR-PRODUCT-NAME-TOO-LONG u11)
(define-constant ERR-DESCRIPTION-TOO-LONG u12)
(define-constant ERR-INVALID-PRODUCT-IDENTIFIER u13)
(define-constant ERR-INVALID-REVIEW-IDENTIFIER u14)

;; SYSTEM CONFIGURATION CONSTANTS

(define-constant min-allowed-rating u1)
(define-constant max-allowed-rating u5)
(define-constant max-reviews-per-page u20)
(define-constant max-product-name-length u50)
(define-constant max-description-length u500)

;; PLATFORM STATE MANAGEMENT

(define-data-var contract-owner principal tx-sender)
(define-data-var global-product-counter uint u1)
(define-data-var global-review-counter uint u1)

;; CORE DATA STRUCTURES

;; Product catalog storage with comprehensive metadata
(define-map product-catalog
  { product-identifier: uint }
  {
    product-title: (string-ascii 50),
    product-summary: (string-ascii 500),
    product-owner: principal,
    creation-block-height: uint,
    status-active: bool
  }
)

;; Review repository with detailed customer feedback
(define-map review-repository
  { review-identifier: uint }
  {
    associated-product: uint,
    review-author: principal,
    customer-rating: uint,
    review-text: (string-ascii 500),
    creation-block-height: uint,
    is-verified-buyer: bool
  }
)

;; Product-review relationship mapping for efficient querying
(define-map product-review-links
  { product-identifier: uint, review-identifier: uint }
  { link-established: bool }
)

;; Aggregated analytics for product performance metrics
(define-map product-analytics
  { product-identifier: uint }
  { 
    total-review-count: uint, 
    aggregate-rating-sum: uint 
  }
)

;; Pagination system for scalable review browsing
(define-map review-page-index
  { product-identifier: uint, page-number: uint }
  { review-id-list: (list 20 uint) }
)

;; DATA VALIDATION UTILITIES

(define-private (product-exists-in-catalog (product-id uint))
  (is-some (map-get? product-catalog { product-identifier: product-id }))
)

(define-private (review-exists-in-repository (review-id uint))
  (is-some (map-get? review-repository { review-identifier: review-id }))
)

(define-private (rating-within-valid-range (rating-value uint))
  (and (>= rating-value min-allowed-rating) (<= rating-value max-allowed-rating))
)

(define-private (validate-product-id (product-id uint))
  (and 
    (>= product-id u1)
    (< product-id (var-get global-product-counter))
    (product-exists-in-catalog product-id)
  )
)

(define-private (validate-review-id (review-id uint))
  (and 
    (>= review-id u1) 
    (< review-id (var-get global-review-counter))
    (review-exists-in-repository review-id)
  )
)

(define-private (validate-product-title (title (string-ascii 50)))
  (and 
    (> (len title) u0)
    (<= (len title) max-product-name-length)
  )
)

(define-private (validate-description-text (description (string-ascii 500)))
  (<= (len description) max-description-length)
)

;; BUSINESS LOGIC PROCESSORS

(define-private (establish-product-review-relationship (product-id uint) (review-id uint) (customer-rating uint))
  (begin
    ;; Comprehensive input validation
    (asserts! (validate-product-id product-id) false)
    (asserts! (validate-review-id review-id) false)
    (asserts! (rating-within-valid-range customer-rating) false)
    
    ;; Create bidirectional relationship mapping
    (map-insert product-review-links 
      { product-identifier: product-id, review-identifier: review-id }
      { link-established: true }
    )
    
    ;; Update real-time analytics and metrics
    (match (map-get? product-analytics { product-identifier: product-id })
      current-analytics (map-set product-analytics 
                          { product-identifier: product-id }
                          { 
                            total-review-count: (+ (get total-review-count current-analytics) u1),
                            aggregate-rating-sum: (+ (get aggregate-rating-sum current-analytics) customer-rating)
                          })
      (map-insert product-analytics 
        { product-identifier: product-id }
        { total-review-count: u1, aggregate-rating-sum: customer-rating })
    )
    
    ;; Manage pagination for optimal data retrieval
    (let 
      (
        (updated-analytics (unwrap-panic (map-get? product-analytics { product-identifier: product-id })))
        (current-total-reviews (get total-review-count updated-analytics))
        (target-page-number (/ (- current-total-reviews u1) max-reviews-per-page))
        (review-position-in-page (mod (- current-total-reviews u1) max-reviews-per-page))
      )
      (match (map-get? review-page-index { product-identifier: product-id, page-number: target-page-number })
        existing-page-content 
          ;; Append to existing page if capacity allows
          (if (< (len (get review-id-list existing-page-content)) max-reviews-per-page)
            (map-set review-page-index
              { product-identifier: product-id, page-number: target-page-number }
              { review-id-list: (unwrap-panic 
                  (as-max-len? 
                    (append (get review-id-list existing-page-content) review-id) 
                    u20)) })
            ;; Initialize new page when current reaches capacity
            (map-insert review-page-index
              { product-identifier: product-id, page-number: (+ u1 target-page-number) }
              { review-id-list: (list review-id) }))
        ;; Bootstrap initial page for new product
        (map-insert review-page-index
          { product-identifier: product-id, page-number: target-page-number }
          { review-id-list: (list review-id) })
      )
    )
    
    true
  )
)

(define-private (verify-product-review-association (product-id uint) (review-id uint))
  (default-to 
    false
    (get link-established (map-get? product-review-links { product-identifier: product-id, review-identifier: review-id }))
  )
)

(define-private (recalculate-analytics-after-removal (product-id uint) (removed-rating uint))
  (begin
    ;; Validate operation parameters
    (asserts! (validate-product-id product-id) false)
    (asserts! (rating-within-valid-range removed-rating) false)
    
    (match (map-get? product-analytics { product-identifier: product-id })
      current-analytics 
        (let 
          (
            (updated-review-total (if (> (get total-review-count current-analytics) u0) 
                                   (- (get total-review-count current-analytics) u1) 
                                   u0))
            (updated-rating-aggregate (if (>= (get aggregate-rating-sum current-analytics) removed-rating)
                                       (- (get aggregate-rating-sum current-analytics) removed-rating)
                                       u0))
          )
          (map-set product-analytics 
            { product-identifier: product-id }
            { total-review-count: updated-review-total, aggregate-rating-sum: updated-rating-aggregate })
          true
        )
      false
    )
  )
)

;; PUBLIC READ-ONLY INTERFACE

(define-read-only (fetch-product-details (product-id uint))
  (if (validate-product-id product-id)
    (map-get? product-catalog { product-identifier: product-id })
    none
  )
)

(define-read-only (fetch-review-details (review-id uint))
  (if (validate-review-id review-id)
    (map-get? review-repository { review-identifier: review-id })
    none
  )
)

(define-read-only (verify-contract-ownership)
  (is-eq tx-sender (var-get contract-owner))
)

(define-read-only (get-product-performance-metrics (product-id uint))
  (if (validate-product-id product-id)
    (default-to 
      { total-review-count: u0, aggregate-rating-sum: u0 } 
      (map-get? product-analytics { product-identifier: product-id }))
    { total-review-count: u0, aggregate-rating-sum: u0 }
  )
)

(define-read-only (calculate-product-average-rating (product-id uint))
  (let 
    (
      (performance-metrics (get-product-performance-metrics product-id))
      (review-total (get total-review-count performance-metrics))
      (rating-aggregate (get aggregate-rating-sum performance-metrics))
    )
    (if (> review-total u0)
      (/ rating-aggregate review-total)
      u0)
  )
)

(define-read-only (calculate-total-review-pages (product-id uint))
  (let 
    (
      (performance-metrics (get-product-performance-metrics product-id))
      (review-total (get total-review-count performance-metrics))
    )
    (+ (/ review-total max-reviews-per-page) 
       (if (> (mod review-total max-reviews-per-page) u0) u1 u0))
  )
)

(define-read-only (fetch-review-ids-for-page (product-id uint) (page-number uint))
  (if (not (validate-product-id product-id))
    { review-id-list: (list) }
    (let 
      (
        (total-pages-available (calculate-total-review-pages product-id))
      )
      (if (or (>= page-number total-pages-available) (is-eq total-pages-available u0))
        { review-id-list: (list) }
        (default-to 
          { review-id-list: (list) } 
          (map-get? review-page-index { product-identifier: product-id, page-number: page-number }))
      )
    )
  )
)

(define-read-only (fetch-complete-reviews-for-page (product-id uint) (page-number uint))
  (if (not (validate-product-id product-id))
    (list)
    (let 
      (
        (page-content (fetch-review-ids-for-page product-id page-number))
        (review-id-collection (get review-id-list page-content))
        (detailed-review-data (map fetch-review-details review-id-collection))
      )
      detailed-review-data
    )
  )
)

;; PLATFORM MANAGEMENT FUNCTIONS

(define-public (create-new-product (product-title (string-ascii 50)) (product-description (string-ascii 500)))
  (let
    (
      (new-product-identifier (var-get global-product-counter))
    )
    ;; Comprehensive input validation
    (asserts! (validate-product-title product-title) (err ERR-PRODUCT-NAME-TOO-LONG))
    (asserts! (validate-description-text product-description) (err ERR-DESCRIPTION-TOO-LONG))
    
    ;; Platform ownership verification
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-UNAUTHORIZED-ACCESS))
    
    ;; Increment global product counter
    (var-set global-product-counter (+ new-product-identifier u1))
    
    ;; Commit product to blockchain catalog
    (ok (map-insert product-catalog 
      { product-identifier: new-product-identifier }
      {
        product-title: product-title,
        product-summary: product-description,
        product-owner: tx-sender,
        creation-block-height: block-height,
        status-active: true
      }
    ))
  )
)

(define-public (update-product-metadata (product-id uint) 
                                       (updated-title (string-ascii 50)) 
                                       (updated-description (string-ascii 500)) 
                                       (activation-status bool))
  (begin
    ;; Input parameter validation
    (asserts! (validate-product-id product-id) (err ERR-INVALID-PRODUCT-IDENTIFIER))
    (asserts! (validate-product-title updated-title) (err ERR-PRODUCT-NAME-TOO-LONG))
    (asserts! (validate-description-text updated-description) (err ERR-DESCRIPTION-TOO-LONG))
    
    (let
      (
        (existing-product-data (map-get? product-catalog { product-identifier: product-id }))
      )
      ;; Product existence verification
      (asserts! (is-some existing-product-data) (err ERR-PRODUCT-NOT-FOUND))
      
      ;; Multi-level authorization check
      (asserts! (or 
        (is-eq tx-sender (var-get contract-owner))
        (is-eq tx-sender (get product-owner (unwrap-panic existing-product-data)))
      ) (err ERR-INSUFFICIENT-PERMISSIONS))
      
      ;; Execute metadata update
      (ok (map-set product-catalog
        { product-identifier: product-id }
        {
          product-title: updated-title,
          product-summary: updated-description,
          product-owner: (get product-owner (unwrap-panic existing-product-data)),
          creation-block-height: (get creation-block-height (unwrap-panic existing-product-data)),
          status-active: activation-status
        }
      ))
    )
  )
)

;; CUSTOMER REVIEW MANAGEMENT

(define-public (publish-customer-review (product-id uint) 
                                       (customer-rating uint) 
                                       (review-commentary (string-ascii 500)) 
                                       (verified-purchase-status bool))
  (begin
    ;; Comprehensive input validation
    (asserts! (validate-product-id product-id) (err ERR-INVALID-PRODUCT-IDENTIFIER))
    (asserts! (rating-within-valid-range customer-rating) (err ERR-INVALID-RATING-SCORE))
    (asserts! (validate-description-text review-commentary) (err ERR-DESCRIPTION-TOO-LONG))
    
    (let
      (
        (new-review-identifier (var-get global-review-counter))
        (target-product-data (map-get? product-catalog { product-identifier: product-id }))
      )
      ;; Product availability validation
      (asserts! (is-some target-product-data) (err ERR-PRODUCT-NOT-FOUND))
      (asserts! (get status-active (unwrap-panic target-product-data)) (err ERR-PRODUCT-INACTIVE))
      
      ;; Increment global review counter
      (var-set global-review-counter (+ new-review-identifier u1))
      
      ;; Commit review to blockchain repository
      (begin
        (map-insert review-repository
          { review-identifier: new-review-identifier }
          {
            associated-product: product-id,
            review-author: tx-sender,
            customer-rating: customer-rating,
            review-text: review-commentary,
            creation-block-height: block-height,
            is-verified-buyer: verified-purchase-status
          }
        )
        
        ;; Establish relationships and update analytics
        (asserts! (establish-product-review-relationship product-id new-review-identifier customer-rating) (err ERR-OPERATION-FAILED))
        
        (ok new-review-identifier)
      )
    )
  )
)

(define-public (update-customer-review (review-id uint) 
                                      (revised-rating uint) 
                                      (revised-commentary (string-ascii 500)))
  (begin
    ;; Input parameter validation
    (asserts! (validate-review-id review-id) (err ERR-INVALID-REVIEW-IDENTIFIER))
    (asserts! (rating-within-valid-range revised-rating) (err ERR-INVALID-RATING-SCORE))
    (asserts! (validate-description-text revised-commentary) (err ERR-DESCRIPTION-TOO-LONG))
    
    (let
      (
        (existing-review-data (map-get? review-repository { review-identifier: review-id }))
      )
      ;; Review existence verification
      (asserts! (is-some existing-review-data) (err ERR-REVIEW-NOT-FOUND))
      
      ;; Author authorization check
      (asserts! (is-eq tx-sender (get review-author (unwrap-panic existing-review-data))) 
                (err ERR-INSUFFICIENT-PERMISSIONS))
      
      ;; Recalculate analytics with updated rating
      (let 
        (
          (review-metadata (unwrap-panic existing-review-data))
          (previous-customer-rating (get customer-rating review-metadata))
          (linked-product-id (get associated-product review-metadata))
          (current-analytics (unwrap-panic (map-get? product-analytics { product-identifier: linked-product-id })))
          (previous-rating-aggregate (get aggregate-rating-sum current-analytics))
          (updated-rating-aggregate (+ (- previous-rating-aggregate previous-customer-rating) revised-rating))
        )
        ;; Update performance analytics
        (map-set product-analytics 
          { product-identifier: linked-product-id }
          { total-review-count: (get total-review-count current-analytics), aggregate-rating-sum: updated-rating-aggregate }
        )
        
        ;; Apply review modifications
        (ok (map-set review-repository
          { review-identifier: review-id }
          {
            associated-product: linked-product-id,
            review-author: tx-sender,
            customer-rating: revised-rating,
            review-text: revised-commentary,
            creation-block-height: (get creation-block-height review-metadata),
            is-verified-buyer: (get is-verified-buyer review-metadata)
          }
        ))
      )
    )
  )
)

(define-public (remove-customer-review (review-id uint))
  (begin
    ;; Input validation
    (asserts! (validate-review-id review-id) (err ERR-INVALID-REVIEW-IDENTIFIER))
    
    (let
      (
        (target-review-data (map-get? review-repository { review-identifier: review-id }))
      )
      ;; Review existence verification
      (asserts! (is-some target-review-data) (err ERR-REVIEW-NOT-FOUND))
      
      ;; Multi-level authorization check
      (asserts! (or 
        (is-eq tx-sender (var-get contract-owner))
        (is-eq tx-sender (get review-author (unwrap-panic target-review-data)))
      ) (err ERR-INSUFFICIENT-PERMISSIONS))
      
      ;; Execute removal and analytics update
      (let
        (
          (review-metadata (unwrap-panic target-review-data))
          (linked-product-id (get associated-product review-metadata))
          (review-rating (get customer-rating review-metadata))
        )
        ;; Recalculate performance metrics
        (asserts! (recalculate-analytics-after-removal linked-product-id review-rating) (err ERR-OPERATION-FAILED))
        
        ;; Remove from all storage maps
        (begin
          (map-delete review-repository { review-identifier: review-id })
          (map-delete product-review-links { 
            product-identifier: linked-product-id, 
            review-identifier: review-id 
          })
          (ok true)
        )
      )
    )
  )
)

;; ADMINISTRATIVE FUNCTIONS

(define-public (transfer-contract-ownership (new-contract-owner principal))
  (begin
    ;; Current owner authorization
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-UNAUTHORIZED-ACCESS))
    
    ;; Prevent transfer to burn address
    (asserts! (not (is-eq new-contract-owner 'SP000000000000000000002Q6VF78)) (err ERR-INVALID-INPUT-DATA))
    
    ;; Execute ownership transfer
    (var-set contract-owner new-contract-owner)
    (ok true)
  )
)