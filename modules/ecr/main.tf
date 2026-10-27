resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)
  name     = each.value

  # A tag (e.g. main-a1b2c3d) can never be overwritten with different code.
  image_tag_mutability = "IMMUTABLE"

  # AWS scans every pushed image for known vulnerabilities.
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Housekeeping: keep only the newest N images per repository.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the newest ${var.keep_last_images} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_last_images
      }
      action = { type = "expire" }
    }]
  })
}
