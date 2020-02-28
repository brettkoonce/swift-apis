#include "tensorflow/compiler/tf2xla/xla_tensor/ops/softshrink.h"

#include "tensorflow/compiler/tf2xla/xla_tensor/elementwise.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/helpers.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/lowering_context.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/ops/scalar.h"

namespace swift_xla {
namespace ir {
namespace ops {

Softshrink::Softshrink(const Value& input, at::Scalar lambda)
    : Node(OpKind(at::aten::softshrink), {input}, input.shape(),
           /*num_outputs=*/1, ScalarHash(lambda)),
      lambda_(std::move(lambda)) {}

std::string Softshrink::ToString() const {
  std::stringstream ss;
  ss << Node::ToString() << ", lambda=" << lambda_;
  return ss.str();
}

NodePtr Softshrink::Clone(OpList operands) const {
  return MakeNode<Softshrink>(operands.at(0), lambda_);
}

XlaOpVector Softshrink::Lower(LoweringContext* loctx) const {
  xla::XlaOp input = loctx->GetOutputOp(operand(0));
  return ReturnOp(BuildSoftshrink(input, lambda_), loctx);
}

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
