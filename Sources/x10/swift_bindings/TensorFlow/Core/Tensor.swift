// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import x10_device

infix operator .==: ComparisonPrecedence
infix operator .!=: ComparisonPrecedence

/// A type-erased tensor for operating over tensors generically.
public struct ErasedTensor {
    init(_xla: XLATensor) {
        xlaTensor = _xla
    }
    var xlaTensor: XLATensor

    /// Prefetches a list of tensors to ensure that it is resident on its specified device.
    public static func prefetch(_ tensors: [ErasedTensor]) {
        XLATensor.prefetch(tensors.map { $0.xlaTensor })
    }
    public var erased: ErasedTensor { self }
}

/// A multidimensional array of elements that is a generalization of vectors and matrices to 
/// potentially higher dimensions.
///
/// The generic parameter `Scalar` describes the type of scalars in the tensor (such as `Int32`,
///  `Float`, etc).
public struct Tensor<Scalar: TensorFlowScalar> {

    init(_xla: XLATensor) {
      precondition(_xla.dtype == Scalar.xlaTensorScalarType,
        "Type mismatch constructing from XLATensor:" +
        "\(_xla.dtype) vs \(Scalar.xlaTensorScalarType)")
      xlaTensor = _xla
    }
    var xlaTensor: XLATensor
}

extension Tensor {
    public var erased: ErasedTensor { ErasedTensor(_xla: xlaTensor) }
    /// Prefetches a tensor to ensure that it is resident on its specified device.
    public func prefetch() { ErasedTensor.prefetch([erased]) }
}

//===------------------------------------------------------------------------------------------===//
// Tensor Properties
//===------------------------------------------------------------------------------------------===//

public extension Tensor {
    /// The number of dimensions of the `Tensor`.
    var rank: Int {
        @_semantics("autodiff.nonvarying")
        get { xlaTensor.shape.count }
    }

    /// The shape of the `Tensor`.
    var shape: TensorShape {
        @_semantics("autodiff.nonvarying")
        get { TensorShape(xlaTensor.shape) }
    }

    /// The number of scalars in the `Tensor`.
    @inlinable
    var scalarCount: Int {
        @_semantics("autodiff.nonvarying")
        get { shape.contiguousSize }
    }

    /// The rank of the tensor, represented as a `Tensor<Int32>`.
    @inlinable
    var rankTensor: Tensor<Int32> {
        @_semantics("autodiff.nonvarying")
        get {
            return _Raw.rank(self)
        }
    }

    /// The dimensions of the tensor, represented as a `Tensor<Int32>`.
    @inlinable
    var shapeTensor: Tensor<Int32> {
        @_semantics("autodiff.nonvarying")
        get {
            return _Raw.shape(self)
        }
    }

    /// The number of scalars in the tensor, represented as a `Tensor<Int32>`.
    @inlinable
    var scalarCountTensor: Tensor<Int32> {
        @_semantics("autodiff.nonvarying")
        get {
            return _Raw.size(self)
        }
    }
}

//===------------------------------------------------------------------------------------------===//
// Scalar Conversion
//===------------------------------------------------------------------------------------------===//

public extension Tensor {
    /// Returns `true` if `rank` is equal to 0 and `false` otherwise.
    @inlinable
    var isScalar: Bool {
        return rank == 0
    }

    /// Returns the single scalar element if `rank` is equal to 0 and `nil`
    /// otherwise.
    @inlinable
    var scalar: Scalar? {
        isScalar ? scalars[0] : nil
    }

    /// Reshape to scalar.
    /// - Precondition: The tensor has exactly one scalar.
    @inlinable
    @differentiable(where Scalar: TensorFlowFloatingPoint)
    func scalarized() -> Scalar {
        precondition(shape.contiguousSize == 1,
           "This tensor must have exactly one scalar but contains \(shape.contiguousSize).")
        return scalars[0]
    }
}

internal extension Tensor where Scalar: TensorFlowFloatingPoint {
    @inlinable
    @derivative(of: scalarized)
    func _vjpScalarized() -> (value: Scalar, pullback: (Scalar) -> Tensor) {
        return (scalarized(), { v in Tensor(v) })
    }
}

public extension TensorFlowScalar {
    @inlinable
    init?(_ tensor: Tensor<Self>) {
        guard let scalar = tensor.scalar else {
            return nil
        }
        self = scalar
    }
}

//===------------------------------------------------------------------------------------------===//
// Array Conversion
//===------------------------------------------------------------------------------------------===//

public extension Tensor {
    @inlinable
    var array: ShapedArray<Scalar> {
        debugLog("Returning a host copy of array.")
        return ShapedArray<Scalar>(shape: shape.dimensions, scalars: scalars)
    }

    @differentiable(where Scalar: TensorFlowFloatingPoint)
    var scalars: [Scalar] {
        let (storage, _) = xlaTensor.fetchTensorValues(Scalar.self)
        return storage
    }
}

extension Tensor where Scalar: TensorFlowFloatingPoint {
    @inlinable
    @derivative(of: scalars)
    func _vjpScalars() -> (value: [Scalar], pullback: (Array<Scalar>.TangentVector) -> Tensor) {
        (value: scalars, pullback: { [shape = self.shape, device = self.device] v in
            Tensor(shape: shape, scalars: v.base, on: device)
        })
    }
}

// Tensor conversion.
public extension Tensor {
    init(_ array: __owned ShapedArray<Scalar>) {
        self.init(shape: TensorShape(array.shape), scalars: array.scalars)
    }
}

//===------------------------------------------------------------------------------------------===//
// Initialization
//===------------------------------------------------------------------------------------------===//

public extension Tensor {
    /// Creates a 0-D tensor from a scalar value.
    @inlinable
    @differentiable(where Scalar: TensorFlowFloatingPoint)
    init(_ value: Scalar, on device: Device = .default) {
        self.init(shape: [], scalars: [value], on: device)
    }
}

internal extension Tensor where Scalar: TensorFlowFloatingPoint {
    @inlinable
    @derivative(of: init(_:on:))
    static func _vjpScalarInit(_ value: __owned Scalar, on device: Device = .default) -> (
        value: Tensor, pullback: (Tensor) -> Scalar
    ) {
        return (Tensor(value, on: device), { $0.scalarized() })
    }
}

public extension Tensor {
    /// Creates a 1D tensor from scalars.
    @inlinable
    @differentiable(where Scalar: TensorFlowFloatingPoint)
    init(_ scalars: [Scalar], on device: Device = .default) {
        self.init(shape: [scalars.count], scalars: scalars, on: device)
    }

    /// Creates a 1D tensor from scalars.
    @inlinable
    init<C: RandomAccessCollection>(
        _ vector: C, on device: Device = .default
    ) where C.Element == Scalar {
      self.init([Scalar](vector), on: device)
    }

    /// Creates a tensor with the specified shape and contiguous scalars in row-major order.
    ///
    /// - Parameters:
    ///   - shape: The shape of the tensor.
    ///   - scalars: The scalar contents of the tensor.
    /// - Precondition: The product of the dimensions of the shape must equal the number of scalars.
    @inlinable
    @differentiable(where Scalar: TensorFlowFloatingPoint)
    init(shape: TensorShape, scalars: [Scalar], on device: Device = .default) {
        precondition(shape.contiguousSize == scalars.count,
            """
            The shape requires \(shape.contiguousSize) scalars but \(scalars.count) were \
            provided.
            """)
        self = scalars.withUnsafeBufferPointer { bufferPointer in
            Tensor(shape: shape, scalars: bufferPointer, on: device)
        }
    }

    /// Creates a tensor with the specified shape and contiguous scalars in row-major order.
    ///
    /// - Parameters:
    ///   - shape: The shape of the tensor.
    ///   - scalars: The scalar contents of the tensor.
    /// - Precondition: The product of the dimensions of the shape must equal the number of scalars.
    init(
        shape: TensorShape,
        scalars: UnsafeBufferPointer<Scalar>,
        on device: Device = .default
    ) {
        precondition(shape.contiguousSize == scalars.count,
            """
            The shape requires \(shape.contiguousSize) scalars but \(scalars.count) were \
            provided.
            """)
        self.init(_xla: XLATensor.make(scalars, shape.dimensions, on: device))
    }

    /// Creates a tensor with the specified shape and contiguous scalars in row-major order.
    ///
    /// - Parameters:
    ///   - shape: The shape of the tensor.
    ///   - scalars: The scalar contents of the tensor.
    /// - Precondition: The product of the dimensions of the shape must equal the number of scalars.
    @inlinable
    init(
        shape: TensorShape,
        scalars: [Scalar],
        toReducedPrecision: Bool,
        directlyOn device: Device
    ) {
        precondition(shape.contiguousSize == scalars.count,
            """
            The shape requires \(shape.contiguousSize) scalars but \(scalars.count) were \
            provided.
            """)
        self = scalars.withUnsafeBufferPointer { bufferPointer in
            Tensor(
                shape: shape, scalars: bufferPointer, toReducedPrecision: toReducedPrecision,
                directlyOn: device)
        }
    }

    /// Creates a tensor with the specified shape and contiguous scalars in row-major order.
    ///
    /// - Parameters:
    ///   - shape: The shape of the tensor.
    ///   - scalars: The scalar contents of the tensor.
    /// - Precondition: The product of the dimensions of the shape must equal the number of scalars.
    init(
        shape: TensorShape,
        scalars: UnsafeBufferPointer<Scalar>,
        toReducedPrecision: Bool,
        directlyOn device: Device
    ) {
        precondition(shape.contiguousSize == scalars.count,
            """
            The shape requires \(shape.contiguousSize) scalars but \(scalars.count) were \
            provided.
            """)
        self.init(
            _xla: XLATensor.make(
                scalars, shape.dimensions, toReducedPrecision: toReducedPrecision,
                directlyOn: device))
    }

    /// Creates a tensor with the specified shape and contiguous scalars in row-major order.
    ///
    /// - Parameters:
    ///   - shape: The shape of the tensor.
    ///   - scalars: The scalar contents of the tensor.
    /// - Precondition: The product of the dimensions of the shape must equal the number of scalars.
    init<C: RandomAccessCollection>(
        shape: TensorShape, scalars: C, on device: Device = .default
    ) where C.Element == Scalar {
        precondition(shape.contiguousSize == scalars.count,
            """
            The shape requires \(shape.contiguousSize) scalars but \(scalars.count) were \
            provided.
            """)
        self.init(shape: shape, scalars: [Scalar](scalars), on: device)
    }
}

extension Tensor where Scalar: TensorFlowFloatingPoint {
    @inlinable
    @derivative(of: init(_:on:))
    static func _vjpInit(_ scalars: [Scalar], on device: Device = .default) -> (
        value: Tensor, pullback: (Tensor) -> Array<Scalar>.TangentVector
    ) {
        (value: Tensor(scalars, on: device), pullback: { v in
            Array<Scalar>.TangentVector(v.scalars)
        })
    }

    @inlinable
    @derivative(of: init(shape:scalars:on:))
    static func _vjpInit(
        shape: TensorShape, scalars: [Scalar], on device: Device = .default
    ) -> (value: Tensor, pullback: (Tensor) -> Array<Scalar>.TangentVector) {
        (value: Tensor(scalars, on: device), pullback: { v in
            Array<Scalar>.TangentVector(v.scalars)
        })
    }
}

// Background story on `TensorElementLiteral` and why it's necessary:
//
// Very importantly, we want users to be able to implicitly convert an array
// literal to a tensor. At first glance, a straightfoward implementation would
// be conforming `Tensor` to `ExpressibleByArrayLiteral` with
// `ExpressibleBy(Float|Int|Bool)Literal` as a base case. However, it is not
// that simple. We have binary operators that take `(Tensor, Scalar)`, `(Scalar,
// Tensor)` as well as `(Tensor, Tensor)`. When `Tensor`s are convertible from
// both a scalar and an array literal, a scalar-tensor binary operator like `+`
// will not type check.
//
// One way to work around it is to define all tensor-tensor operators in a
// protocol extension, and all tensor-scalar and scalar-tensor operators on
// concrete `Tensor`. Protocol extensions are less favorable than concrete
// implementations, so the compiler will prefer the concrete implementation for
// a scalar-tensor operation. However, this would cause enormous code bloat and
// is entirely a hack.
//
// To resolve ambiguity, `Tensor` should not be expressible by scalar literal.
// There's already a lightweight syntax for converting a scalar to a tensor:
// `Tensor(x)`, so there is no strong need for implicit conversion. But we need
// to find a way to give `ExpressibleByArrayLiteral` a base case: what would the
// `ArrayLiteralElement` be if we want to support both `[1,2,3]` and `[[[1,2],
// [1,2]]]`? In the first case the array literal element is an interger, while
// in the second case the array literal itself should be a tensor. Based on this
// observation, we come up with an intermediate type: `TensorElementLiteral` as
// the `ArrayLiteralElement` of `Tensor`. By making `TensorElementLiteral`
// expressible by both array literal and scalar literal, `Tensor` can now be
// converted from an arbitrary-dimensional array literal.
//
// Due to protocol requirements, `TensorElementLiteral` has to be
// public. It is never supposed to be used directly by any user, so the library
// convention is to prepend an underscore to its name, making it
// `_TensorElementLiteral`.
//
// It would be nice to be able to remove this type when we can systematically
// resolve tensor-scalar/scalar-tensor op ambiguity someday, either through an
// improved `Expressible` model, or by introducing an attribute to tell the type
// checker which function to prefer when ambiguity occurs.

/// Represents a literal element for conversion to a `Tensor`.
///
/// - Note: Do not ever use this API directly. This is implicitly created
///   during the conversion from an array literal to a `Tensor`, and is purely
///   for implementation purposes.
@frozen
public struct _TensorElementLiteral<Scalar> where Scalar: TensorFlowScalar {
    @usableFromInline let tensor: Tensor<Scalar>
}

extension _TensorElementLiteral: ExpressibleByBooleanLiteral
    where Scalar: ExpressibleByBooleanLiteral {
    public typealias BooleanLiteralType = Scalar.BooleanLiteralType
    @inlinable
    public init(booleanLiteral: BooleanLiteralType) {
        tensor = Tensor(Scalar(booleanLiteral: booleanLiteral))
    }
}

extension _TensorElementLiteral: ExpressibleByIntegerLiteral
    where Scalar: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Scalar.IntegerLiteralType
    @inlinable
    public init(integerLiteral: IntegerLiteralType) {
        tensor = Tensor(Scalar(integerLiteral: integerLiteral))
    }
}

extension _TensorElementLiteral: ExpressibleByFloatLiteral
    where Scalar: ExpressibleByFloatLiteral {
    public typealias FloatLiteralType = Scalar.FloatLiteralType
    @inlinable
    public init(floatLiteral: FloatLiteralType) {
        tensor = Tensor(Scalar(floatLiteral: floatLiteral))
    }
}

extension _TensorElementLiteral: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = _TensorElementLiteral<Scalar>
    @inlinable
    public init(arrayLiteral elements: _TensorElementLiteral<Scalar>...) {
        tensor = _Raw.pack(elements.map { $0.tensor })
    }
}

extension Tensor: ExpressibleByArrayLiteral {
    /// The type of the elements of an array literal.
    public typealias ArrayLiteralElement = _TensorElementLiteral<Scalar>

    /// Creates a tensor initialized with the given elements.
    /// - Note: This is for conversion from tensor element literals. This is a
    ///   separate method because `ShapedArray` initializers need to call it.
    @inlinable
    internal init(_tensorElementLiterals elements: [_TensorElementLiteral<Scalar>]) {
        self = _Raw.pack(elements.map { $0.tensor })
    }

    /// Creates a tensor initialized with the given elements.
    @inlinable
    public init(arrayLiteral elements: _TensorElementLiteral<Scalar>...) {
        precondition(!elements.isEmpty, "Cannot create a 'Tensor' with no elements.")
        self.init(_tensorElementLiterals: elements)
    }
}

//===------------------------------------------------------------------------------------------===//
// Equatable
//===------------------------------------------------------------------------------------------===//

extension Tensor: Equatable where Scalar: Equatable {
    @inlinable
    public static func == (lhs: Tensor, rhs: Tensor) -> Bool {
        guard lhs.shape == rhs.shape else {
            return false
        }
        return (lhs .== rhs).all()
    }

    @inlinable
    public static func != (lhs: Tensor, rhs: Tensor) -> Bool {
        guard lhs.shape == rhs.shape else {
            return true
        }
        return (lhs .!= rhs).any()
    }
}

//===------------------------------------------------------------------------------------------===//
// Description and Visualization
//===------------------------------------------------------------------------------------------===//

// String conversion.
extension Tensor: CustomStringConvertible {
    /// A textual representation of the tensor.
    ///
    /// - Note: use `fullDescription` for a non-pretty-printed description showing all scalars.
    public var description: String {
        @_semantics("autodiff.nonvarying")
        get {
            return array.description
        }
    }
}

public extension Tensor {
    /// A textual representation of the tensor. Returns a summarized description if `summarize` is
    /// true and the element count exceeds twice the `edgeElementCount`.
    ///
    /// - Parameters:
    ///   - lineWidth: The max line width for printing. Used to determine number of scalars to print
    ///     per line.
    ///   - edgeElementCount: The maximum number of elements to print before and after summarization
    ///     via ellipses (`...`).
    ///   - summarizing: If true, summarize description if element count exceeds twice
    ///     `edgeElementCount`.
    func description(
        lineWidth: Int = 80,
        edgeElementCount: Int = 3,
        summarizing: Bool = false
    ) -> String {
        return array.description(
            lineWidth: lineWidth,
            edgeElementCount: edgeElementCount,
            summarizing: summarizing)
    }

    /// A full, non-pretty-printed textual representation of the tensor, showing
    /// all scalars.
    var fullDescription: String {
        @_semantics("autodiff.nonvarying")
        get {
            return array.fullDescription
        }
    }

    var irText: String { XLATensor.irText(xlaTensor) }
}

// Xcode Playground display conversion.
extension Tensor: CustomPlaygroundDisplayConvertible {
    public var playgroundDescription: Any {
        @_semantics("autodiff.nonvarying")
        get {
            return description
        }
    }
}

// Mirror representation, used by debugger/REPL.
extension Tensor: CustomReflectable {
    public var customMirror: Mirror {
        @_semantics("autodiff.nonvarying")
        get {
            return Mirror(self, children: [], displayStyle: .struct)
        }
    }
}

//===------------------------------------------------------------------------------------------===//
// Codable Conformance
//===------------------------------------------------------------------------------------------===//

extension Tensor: Codable where Scalar: Codable {
    @inlinable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(array)
    }

    @inlinable
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let array = try container.decode(ShapedArray<Scalar>.self)
        self.init(array)
    }
}

//===------------------------------------------------------------------------------------------===//
// Additive Group
//===------------------------------------------------------------------------------------------===//

extension Tensor: AdditiveArithmetic where Scalar: Numeric {
    /// The scalar zero tensor.
    public static var zero: Tensor {
        var zero = Tensor(0, on: _ThreadLocalState.local.currentDevice)
        if _ThreadLocalState.local.isReducedPrecision {
            zero = zero.toReducedPrecision
        }
        return zero
    }

    /// Adds two tensors and produces their sum.
    /// - Note: `+` supports broadcasting.
    @inlinable
    @differentiable(where Scalar: TensorFlowFloatingPoint)
    public static func + (lhs: Tensor, rhs: Tensor) -> Tensor {
        _Raw.addV2(lhs, rhs)
    }

    /// Subtracts one tensor from another and produces their difference.
    /// - Note: `-` supports broadcasting.
    @inlinable
    @differentiable(where Scalar: TensorFlowFloatingPoint)
    public static func - (lhs: Tensor, rhs: Tensor) -> Tensor {
        _Raw.sub(lhs, rhs)
    }
}

internal extension Tensor where Scalar: TensorFlowFloatingPoint {
    @inlinable
    @derivative(of: +)
    static func _vjpAdd(lhs: Tensor, rhs: Tensor) -> (
        value: Tensor, pullback: (Tensor) -> (Tensor, Tensor)
    ) {
        (lhs + rhs, { [broadcastPb = BroadcastingPullback(lhs, rhs)] v in
            return broadcastPb(v, v)
        })
    }

    @inlinable
    @derivative(of: -)
    static func _vjpSubtract(lhs: Tensor, rhs: Tensor) -> (
        value: Tensor, pullback: (Tensor) -> (Tensor, Tensor)
    ) {
        (lhs - rhs, { [broadcastPb = BroadcastingPullback(lhs, rhs)] v in
            return broadcastPb(v, -v)
        })
    }
}

//===------------------------------------------------------------------------------------------===//
// Multiplicative Group
//===------------------------------------------------------------------------------------------===//

extension Tensor: PointwiseMultiplicative where Scalar: Numeric {
    /// The scalar one tensor.
    @inlinable
    public static var one: Tensor { Tensor(1) }

    /// Returns the element-wise reciprocal of `self`.
    @inlinable
    public var reciprocal: Tensor { 1 / self }

    /// Multiplies two tensors element-wise and produces their product.
    /// - Note: `.*` supports broadcasting.
    public static func .* (lhs: Tensor, rhs: Tensor) -> Tensor {
        return lhs * rhs
    }
}

//===------------------------------------------------------------------------------------------===//
// Differentiable
//===------------------------------------------------------------------------------------------===//

extension Tensor: Differentiable & EuclideanDifferentiable where Scalar: TensorFlowFloatingPoint {
    public typealias TangentVector = Tensor
}

//===------------------------------------------------------------------------------------------===//
// Multi-device support
//===------------------------------------------------------------------------------------------===//

extension Tensor {
    /// The device on which `self` is allocated.
    public var device: Device {
        @_semantics("autodiff.nonvarying")
        get {
            return xlaTensor.device
        }
    }
}
