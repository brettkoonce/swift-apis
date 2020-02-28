#pragma once

#include "absl/types/optional.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/ir.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/reduction.h"

namespace swift_xla {
namespace ir {
namespace ops {

class BinaryCrossEntropy : public Node {
 public:
  BinaryCrossEntropy(const Value& logits, const Value& labels,
                     const absl::optional<Value>& weight,
                     ReductionMode reduction);

  std::string ToString() const override;

  NodePtr Clone(OpList operands) const override;

  XlaOpVector Lower(LoweringContext* loctx) const override;

  ReductionMode reduction() const { return reduction_; }

 private:
  ReductionMode reduction_;
};

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
