#pragma once

#include "tensorflow/compiler/tf2xla/xla_tensor/ir.h"

namespace swift_xla {
namespace ir {
namespace ops {

class ArgMax : public Node {
 public:
  ArgMax(const Value& input, xla::int64 dim, bool keepdim);

  std::string ToString() const override;

  NodePtr Clone(OpList operands) const override;

  XlaOpVector Lower(LoweringContext* loctx) const override;

  xla::int64 dim() const { return dim_; };

  bool keepdim() const { return keepdim_; }

 private:
  xla::int64 dim_;
  bool keepdim_;
};

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
