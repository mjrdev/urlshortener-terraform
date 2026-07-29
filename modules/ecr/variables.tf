variable "name" {
  type = string
}

variable "immutable_tags" {
  description = "Se true, uma tag publicada nao pode ser sobrescrita."
  type        = bool
  default     = false
}