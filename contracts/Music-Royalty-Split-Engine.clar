(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SONG_NOT_FOUND (err u101))
(define-constant ERR_INVALID_SPLIT (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_ALREADY_EXISTS (err u104))
(define-constant ERR_INVALID_CONTRIBUTOR (err u105))

(define-constant ERR_NOT_VESTED (err u106))
(define-constant ERR_ALREADY_CLAIMED (err u107))
(define-constant ERR_INVALID_VESTING (err u108))

(define-constant ERR_NOT_SIGNER (err u109))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u110))
(define-constant ERR_ALREADY_APPROVED (err u111))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u112))
(define-constant ERR_PROPOSAL_EXECUTED (err u113))

(define-data-var required-approvals uint u2)
(define-data-var proposal-counter uint u0)

(define-data-var contract-owner principal tx-sender)

(define-map songs 
  { song-id: uint }
  { 
    title: (string-ascii 128),
    artist: (string-ascii 64),
    total-splits: uint,
    created-at: uint,
    total-distributed: uint
  }
)

(define-map contributors
  { song-id: uint, contributor: principal }
  { split-percentage: uint, total-received: uint }
)

(define-map song-counter uint uint)

(define-map royalty-distributions
  { song-id: uint, distribution-id: uint }
  { 
    amount: uint,
    timestamp: uint,
    distributor: principal
  }
)

(define-map distribution-counter { song-id: uint } uint)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-song-details (song-id uint))
  (map-get? songs { song-id: song-id })
)

(define-read-only (get-contributor-info (song-id uint) (contributor principal))
  (map-get? contributors { song-id: song-id, contributor: contributor })
)

(define-read-only (get-total-songs)
  (default-to u0 (map-get? song-counter u0))
)

(define-read-only (get-distribution-history (song-id uint) (distribution-id uint))
  (map-get? royalty-distributions { song-id: song-id, distribution-id: distribution-id })
)

(define-read-only (get-next-distribution-id (song-id uint))
  (default-to u0 (map-get? distribution-counter { song-id: song-id }))
)

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (validate-splits (contributors-list (list 20 { contributor: principal, split: uint })))
  (let ((total-split (fold + (map get-split contributors-list) u0)))
    (is-eq total-split u10000)
  )
)

(define-private (get-split (contributor-data { contributor: principal, split: uint }))
  (get split contributor-data)
)

(define-public (register-song 
  (title (string-ascii 128))
  (artist (string-ascii 64))
  (contributors-list (list 20 { contributor: principal, split: uint }))
)
  (let 
    (
      (song-id (+ (get-total-songs) u1))
      (current-block burn-block-height)
    )
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (validate-splits contributors-list) ERR_INVALID_SPLIT)
    
    (map-set songs 
      { song-id: song-id }
      { 
        title: title,
        artist: artist,
        total-splits: (len contributors-list),
        created-at: current-block,
        total-distributed: u0
      }
    )
    
    (map-set song-counter u0 song-id)
    (map-set distribution-counter { song-id: song-id } u0)
    
    (fold register-contributors contributors-list song-id)
    
    (ok song-id)
  )
)

(define-private (register-contributors 
  (contributor-data { contributor: principal, split: uint })
  (song-id uint)
)
  (begin
    (map-set contributors
      { song-id: song-id, contributor: (get contributor contributor-data) }
      { split-percentage: (get split contributor-data), total-received: u0 }
    )
    song-id
  )
)

(define-public (distribute-royalties (song-id uint) (total-amount uint))
  (let 
    (
      (song-data (unwrap! (get-song-details song-id) ERR_SONG_NOT_FOUND))
      (distribution-id (+ (get-next-distribution-id song-id) u1))
      (current-block burn-block-height)
    )
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (>= (stx-get-balance tx-sender) total-amount) ERR_INSUFFICIENT_FUNDS)
    
    (map-set royalty-distributions
      { song-id: song-id, distribution-id: distribution-id }
      {
        amount: total-amount,
        timestamp: current-block,
        distributor: tx-sender
      }
    )
    
    (map-set distribution-counter { song-id: song-id } distribution-id)
    
    (map-set songs 
      { song-id: song-id }
      (merge song-data { total-distributed: (+ (get total-distributed song-data) total-amount) })
    )
    
    (ok distribution-id)
  )
)

(define-public (claim-royalty (song-id uint) (distribution-id uint))
  (let 
    (
      (contributor-data (unwrap! (get-contributor-info song-id tx-sender) ERR_INVALID_CONTRIBUTOR))
      (distribution-data (unwrap! (get-distribution-history song-id distribution-id) ERR_SONG_NOT_FOUND))
      (total-amount (get amount distribution-data))
      (split-percentage (get split-percentage contributor-data))
      (claim-amount (/ (* total-amount split-percentage) u10000))
    )
    
    (try! (stx-transfer? claim-amount (get distributor distribution-data) tx-sender))
    
    (map-set contributors
      { song-id: song-id, contributor: tx-sender }
      (merge contributor-data { total-received: (+ (get total-received contributor-data) claim-amount) })
    )
    
    (ok claim-amount)
  )
)

(define-public (update-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-read-only (calculate-share (song-id uint) (amount uint) (contributor principal))
  (match (get-contributor-info song-id contributor)
    contributor-data 
      (ok (/ (* amount (get split-percentage contributor-data)) u10000))
    ERR_INVALID_CONTRIBUTOR
  )
)


(define-map vesting-schedules
  { song-id: uint, distribution-id: uint, contributor: principal }
  {
    total-amount: uint,
    start-block: uint,
    cliff-blocks: uint,
    vesting-blocks: uint,
    claimed-amount: uint
  }
)

(define-read-only (get-vesting-details (song-id uint) (distribution-id uint) (contributor principal))
  (map-get? vesting-schedules { song-id: song-id, distribution-id: distribution-id, contributor: contributor })
)

(define-read-only (get-vested-amount (song-id uint) (distribution-id uint) (contributor principal))
  (match (get-vesting-details song-id distribution-id contributor)
    schedule
      (let
        (
          (current-block burn-block-height)
          (start-block (get start-block schedule))
          (cliff-blocks (get cliff-blocks schedule))
          (vesting-blocks (get vesting-blocks schedule))
          (total-amount (get total-amount schedule))
          (claimed-amount (get claimed-amount schedule))
          (cliff-end (+ start-block cliff-blocks))
          (vesting-end (+ cliff-end vesting-blocks))
        )
        (if (< current-block cliff-end)
          (ok u0)
          (if (>= current-block vesting-end)
            (ok (- total-amount claimed-amount))
            (let
              (
                (blocks-since-cliff (- current-block cliff-end))
                (vested-amount (/ (* total-amount blocks-since-cliff) vesting-blocks))
                (claimable (- vested-amount claimed-amount))
              )
              (ok claimable)
            )
          )
        )
      )
    (ok u0)
  )
)

(define-public (create-vesting-schedule 
  (song-id uint)
  (distribution-id uint)
  (contributor principal)
  (amount uint)
  (cliff-blocks uint)
  (vesting-blocks uint)
)
  (let
    (
      (start-block burn-block-height)
    )
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_VESTING)
    (asserts! (> vesting-blocks u0) ERR_INVALID_VESTING)
    
    (map-set vesting-schedules
      { song-id: song-id, distribution-id: distribution-id, contributor: contributor }
      {
        total-amount: amount,
        start-block: start-block,
        cliff-blocks: cliff-blocks,
        vesting-blocks: vesting-blocks,
        claimed-amount: u0
      }
    )
    (ok true)
  )
)

(define-public (claim-vested-royalty (song-id uint) (distribution-id uint))
  (let
    (
      (schedule (unwrap! (get-vesting-details song-id distribution-id tx-sender) ERR_SONG_NOT_FOUND))
      (claimable-amount (unwrap! (get-vested-amount song-id distribution-id tx-sender) ERR_NOT_VESTED))
      (distribution-data (unwrap! (get-distribution-history song-id distribution-id) ERR_SONG_NOT_FOUND))
    )
    (asserts! (> claimable-amount u0) ERR_NOT_VESTED)
    
    (try! (stx-transfer? claimable-amount (get distributor distribution-data) tx-sender))
    
    (map-set vesting-schedules
      { song-id: song-id, distribution-id: distribution-id, contributor: tx-sender }
      (merge schedule { claimed-amount: (+ (get claimed-amount schedule) claimable-amount) })
    )
    
    (ok claimable-amount)
  )
)


(define-map authorized-signers principal bool)

(define-map song-proposals
  { proposal-id: uint }
  {
    title: (string-ascii 128),
    artist: (string-ascii 64),
    contributors-list: (list 20 { contributor: principal, split: uint }),
    proposer: principal,
    approval-count: uint,
    executed: bool,
    created-at: uint
  }
)

(define-map proposal-approvals
  { proposal-id: uint, signer: principal }
  bool
)

(define-read-only (is-authorized-signer (signer principal))
  (default-to false (map-get? authorized-signers signer))
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? song-proposals { proposal-id: proposal-id })
)

(define-read-only (has-approved (proposal-id uint) (signer principal))
  (default-to false (map-get? proposal-approvals { proposal-id: proposal-id, signer: signer }))
)

(define-public (add-signer (new-signer principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (map-set authorized-signers new-signer true)
    (ok true)
  )
)

(define-public (propose-song-registration
  (title (string-ascii 128))
  (artist (string-ascii 64))
  (contributors-list (list 20 { contributor: principal, split: uint }))
)
  (let ((proposal-id (+ (var-get proposal-counter) u1)))
    (asserts! (is-authorized-signer tx-sender) ERR_NOT_SIGNER)
    (asserts! (validate-splits contributors-list) ERR_INVALID_SPLIT)
    
    (map-set song-proposals
      { proposal-id: proposal-id }
      {
        title: title,
        artist: artist,
        contributors-list: contributors-list,
        proposer: tx-sender,
        approval-count: u0,
        executed: false,
        created-at: burn-block-height
      }
    )
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (approve-proposal (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-authorized-signer tx-sender) ERR_NOT_SIGNER)
    (asserts! (not (has-approved proposal-id tx-sender)) ERR_ALREADY_APPROVED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)
    
    (map-set proposal-approvals { proposal-id: proposal-id, signer: tx-sender } true)
    (map-set song-proposals
      { proposal-id: proposal-id }
      (merge proposal { approval-count: (+ (get approval-count proposal) u1) })
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (>= (get approval-count proposal) (var-get required-approvals)) ERR_INSUFFICIENT_APPROVALS)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)
    
    (try! (register-song (get title proposal) (get artist proposal) (get contributors-list proposal)))
    
    (map-set song-proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    (ok true)
  )
)