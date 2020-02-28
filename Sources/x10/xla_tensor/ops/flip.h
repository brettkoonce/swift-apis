#pragma once

#include "absl/types/span.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/ir.h"

namespace swift_xla {
namespace ir {
namespace ops {

class Flip : public Node {
 public:
  Flip(const Value& input, std::vector<xla::int64> dims);

  NodePtr Clone(OpList operands) const override;

  XlaOpVector Lower(LoweringContext* loctx) const override;

  std::string ToString() const override;

  const std::vector<xla::int64>& dims() const { return dims_; }

 private:
  // The dimensions which are flipped.
  std::vector<xla::int64> dims_;
};

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
