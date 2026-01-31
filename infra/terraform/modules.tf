# =============================================================================
# Module Declarations
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Module
# -----------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Route 53 Module
# -----------------------------------------------------------------------------

module "route53" {
  source = "./modules/route53"

  project_name       = var.project_name
  environment        = var.environment
  domain_name        = var.domain_name
  create_hosted_zone = var.create_hosted_zone
  hosted_zone_id     = var.hosted_zone_id

  # CloudFront alias target (if enabled)
  cloudfront_domain_name    = var.enable_cloudfront ? module.cloudfront[0].domain_name : null
  cloudfront_hosted_zone_id = var.enable_cloudfront ? module.cloudfront[0].hosted_zone_id : null

  tags = local.common_tags

  depends_on = [module.cloudfront]
}

# -----------------------------------------------------------------------------
# ACM Certificate Module
# -----------------------------------------------------------------------------

module "acm" {
  source = "./modules/acm"

  project_name       = var.project_name
  environment        = var.environment
  domain_name        = var.domain_name
  create_certificate = var.create_certificate
  certificate_arn    = var.certificate_arn
  hosted_zone_id     = var.create_hosted_zone ? module.route53.hosted_zone_id : var.hosted_zone_id

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# S3 Module (for static hosting)
# -----------------------------------------------------------------------------

module "s3" {
  source = "./modules/s3"
  count  = var.enable_s3_hosting ? 1 : 0

  project_name = var.project_name
  environment  = var.environment

  # CloudFront OAI for secure access
  cloudfront_oai_arn = var.enable_cloudfront ? module.cloudfront[0].origin_access_identity_arn : null

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# CloudFront Module
# -----------------------------------------------------------------------------

module "cloudfront" {
  source = "./modules/cloudfront"
  count  = var.enable_cloudfront ? 1 : 0

  project_name    = var.project_name
  environment     = var.environment
  domain_name     = var.domain_name
  certificate_arn = module.acm.certificate_arn
  price_class     = var.cloudfront_price_class

  # S3 origin
  s3_bucket_regional_domain_name = var.enable_s3_hosting ? module.s3[0].bucket_regional_domain_name : null
  s3_bucket_id                   = var.enable_s3_hosting ? module.s3[0].bucket_id : null

  tags = local.common_tags

  depends_on = [module.acm, module.s3]
}
