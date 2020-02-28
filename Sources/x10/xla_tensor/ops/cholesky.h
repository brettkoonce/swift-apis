#pragma once

#include "tensorflow/compiler/tf2xla/xla_tensor/ir.h"

namespace swift_xla {
namespace ir {
namespace ops {

class Cholesky : public Node {
 public:
  Cholesky(const Value& input, bool lower);

  std::string ToString() const override;

  NodePtr Clone(OpList operands) const override;

  XlaOpVector Lower(LoweringContext* loctx) const override;

  bool lower() const { return lower_; }

 private:
  bool lower_;
};

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
