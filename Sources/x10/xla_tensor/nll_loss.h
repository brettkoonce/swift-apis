#pragma once

#include "absl/types/optional.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/reduction.h"
#include "tensorflow/compiler/xla/client/xla_builder.h"

namespace swift_xla {

// Builds the NLLLoss for log-probabilities "logits" and class indices "labels".
xla::XlaOp BuildNllLoss(xla::XlaOp logits, xla::XlaOp labels,
                        const absl::optional<xla::XlaOp>& weight,
                        int ignore_index, ReductionMode reduction_mode);

// Builds the NLLLoss gradient for log-probabilities "logits" and class indices
// "labels".
xla::XlaOp BuildNllLossBackward(xla::XlaOp grad_output, xla::XlaOp logits,
                                xla::XlaOp labels,
                                const absl::optional<xla::XlaOp>& weight,
                                const absl::optional<xla::XlaOp>& total_weight,
                                int ignore_index, ReductionMode reduction_mode);

}  // namespace swift_xla
