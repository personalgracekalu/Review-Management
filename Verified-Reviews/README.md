# ReviewForge Product Review Platform

A comprehensive blockchain-powered product review ecosystem built on the Stacks blockchain using Clarity smart contracts.

## Overview

ReviewForge provides an immutable, transparent, and decentralized platform for product reviews with the following key features:

- **Immutable Product Catalog**: Transparent product registration and management
- **Authentic Customer Reviews**: Verified rating systems with tamper-proof storage
- **Real-time Analytics**: Automated aggregation of review metrics and statistics
- **Scalable Architecture**: Paginated review browsing for optimal performance
- **Multi-level Governance**: Administrative controls with ownership verification
- **Community-driven**: Decentralized content moderation system

## Key Features

### Product Management
- Create and register products with metadata
- Update product information and status
- Multi-level authorization (owner and admin)
- Product activation/deactivation controls

### Review System
- Submit authentic customer reviews with 1-5 star ratings
- Verified buyer status tracking
- Review editing and deletion capabilities
- Immutable storage on blockchain

### Analytics & Metrics
- Real-time review count tracking
- Automatic average rating calculations
- Performance metrics aggregation
- Historical data preservation

### 📄 Pagination System
- Efficient review browsing with configurable page sizes
- Scalable data retrieval for large review sets
- Optimized storage management

## Technical Specifications

### Rating System
- **Minimum Rating**: 1 star
- **Maximum Rating**: 5 stars
- **Reviews per Page**: 20 (configurable)

### Data Limits
- **Product Name**: Maximum 50 characters
- **Description/Review Text**: Maximum 500 characters

## Smart Contract Interface

### Core Data Structures

#### Product Catalog
```clarity
{
  product-title: (string-ascii 50),
  product-summary: (string-ascii 500),
  product-owner: principal,
  creation-block-height: uint,
  status-active: bool
}
```

#### Review Repository
```clarity
{
  associated-product: uint,
  review-author: principal,
  customer-rating: uint,
  review-text: (string-ascii 500),
  creation-block-height: uint,
  is-verified-buyer: bool
}
```

### Public Functions

#### Product Management

**`create-new-product`**
```clarity
(create-new-product (product-title (string-ascii 50)) (product-description (string-ascii 500)))
```
- **Access**: Contract owner only
- **Purpose**: Register a new product in the catalog
- **Returns**: Success confirmation

**`update-product-metadata`**
```clarity
(update-product-metadata (product-id uint) (updated-title (string-ascii 50)) 
                        (updated-description (string-ascii 500)) (activation-status bool))
```
- **Access**: Contract owner or product owner
- **Purpose**: Modify existing product information
- **Returns**: Success confirmation

#### Review Management

**`publish-customer-review`**
```clarity
(publish-customer-review (product-id uint) (customer-rating uint) 
                        (review-commentary (string-ascii 500)) (verified-purchase-status bool))
```
- **Access**: Any user
- **Purpose**: Submit a new product review
- **Returns**: New review ID

**`update-customer-review`**
```clarity
(update-customer-review (review-id uint) (revised-rating uint) (revised-commentary (string-ascii 500)))
```
- **Access**: Original review author
- **Purpose**: Modify existing review content and rating
- **Returns**: Success confirmation

**`remove-customer-review`**
```clarity
(remove-customer-review (review-id uint))
```
- **Access**: Contract owner or review author
- **Purpose**: Delete a review and update analytics
- **Returns**: Success confirmation

#### Administrative Functions

**`transfer-contract-ownership`**
```clarity
(transfer-contract-ownership (new-contract-owner principal))
```
- **Access**: Current contract owner only
- **Purpose**: Transfer platform ownership
- **Returns**: Success confirmation

### Read-Only Functions

#### Data Retrieval

**`fetch-product-details`**
```clarity
(fetch-product-details (product-id uint))
```
- **Returns**: Complete product information or none

**`fetch-review-details`**
```clarity
(fetch-review-details (review-id uint))
```
- **Returns**: Complete review information or none

**`get-product-performance-metrics`**
```clarity
(get-product-performance-metrics (product-id uint))
```
- **Returns**: Total review count and aggregate rating sum

**`calculate-product-average-rating`**
```clarity
(calculate-product-average-rating (product-id uint))
```
- **Returns**: Calculated average rating for the product

#### Pagination Support

**`calculate-total-review-pages`**
```clarity
(calculate-total-review-pages (product-id uint))
```
- **Returns**: Total number of review pages for pagination

**`fetch-review-ids-for-page`**
```clarity
(fetch-review-ids-for-page (product-id uint) (page-number uint))
```
- **Returns**: List of review IDs for specified page

**`fetch-complete-reviews-for-page`**
```clarity
(fetch-complete-reviews-for-page (product-id uint) (page-number uint))
```
- **Returns**: Complete review data for specified page

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u1 | ERR-UNAUTHORIZED-ACCESS | Insufficient permissions for operation |
| u2 | ERR-PRODUCT-NOT-FOUND | Product does not exist |
| u3 | ERR-INSUFFICIENT-PERMISSIONS | User lacks required permissions |
| u4 | ERR-INVALID-RATING-SCORE | Rating outside valid range (1-5) |
| u5 | ERR-REVIEW-NOT-FOUND | Review does not exist |
| u6 | ERR-PRODUCT-ALREADY-REGISTERED | Product ID already in use |
| u7 | ERR-PRODUCT-INACTIVE | Product is not active |
| u8 | ERR-OPERATION-FAILED | General operation failure |
| u9 | ERR-INVALID-PAGE-NUMBER | Page number out of range |
| u10 | ERR-INVALID-INPUT-DATA | Invalid input parameters |
| u11 | ERR-PRODUCT-NAME-TOO-LONG | Product name exceeds limit |
| u12 | ERR-DESCRIPTION-TOO-LONG | Description exceeds limit |
| u13 | ERR-INVALID-PRODUCT-IDENTIFIER | Invalid product ID |
| u14 | ERR-INVALID-REVIEW-IDENTIFIER | Invalid review ID |

## Usage Examples

### Creating a Product
```clarity
(contract-call? .reviewforge create-new-product 
  "iPhone 15 Pro" 
  "Latest Apple smartphone with advanced camera system")
```

### Submitting a Review
```clarity
(contract-call? .reviewforge publish-customer-review 
  u1          ;; product-id
  u5          ;; 5-star rating
  "Excellent product! Highly recommended for photography enthusiasts."
  true)       ;; verified buyer
```

### Fetching Product Reviews (Page 1)
```clarity
(contract-call? .reviewforge fetch-complete-reviews-for-page u1 u0)
```

### Getting Product Statistics
```clarity
(contract-call? .reviewforge calculate-product-average-rating u1)
(contract-call? .reviewforge get-product-performance-metrics u1)
```

## Security Features

- **Ownership Verification**: Multi-level access controls
- **Input Validation**: Comprehensive parameter checking
- **Data Integrity**: Immutable blockchain storage
- **Tamper Protection**: Cryptographic security via Stacks blockchain
- **Authorization Checks**: Function-level permission management

## Deployment Considerations

1. **Initial Setup**: Deploy contract and set initial owner
2. **Product Registration**: Owner creates initial product catalog
3. **Community Growth**: Users submit and manage reviews
4. **Governance**: Transfer ownership as needed for decentralization