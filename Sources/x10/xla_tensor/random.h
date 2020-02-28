#pragma once

#include "tensorflow/compiler/xla/client/xla_builder.h"

namespace swift_xla {

xla::XlaOp RngUniform(xla::XlaOp seed, const xla::Shape& shape,
                      xla::XlaOp minval, xla::XlaOp maxval);

}  // namespace swift_xla
