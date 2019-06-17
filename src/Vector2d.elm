--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- This Source Code Form is subject to the terms of the Mozilla Public        --
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,  --
-- you can obtain one at http://mozilla.org/MPL/2.0/.                         --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


module Vector2d exposing
    ( Vector2d
    , zero
    , fromComponents, fromComponentsIn, fromPolarComponents, fromPolarComponentsIn, from, withLength, perpendicularTo, interpolateFrom
    , fromTuple, toTuple, fromRecord, toRecord
    , at, at_
    , per, for
    , xComponent, yComponent, componentIn, polarComponents, length, direction, lengthAndDirection
    , equalWithin, lexicographicComparison
    , plus, minus, dot, cross
    , reverse, normalize, scaleBy, rotateBy, rotateClockwise, rotateCounterclockwise, mirrorAcross, projectionIn, projectOnto
    , relativeTo, placeIn
    )

{-| A `Vector2d` represents a quantity such as a displacement or velocity in 2D,
and is defined by its X and Y components. This module contains a variety of
vector-related functionality, such as

  - Adding or subtracting vectors
  - Finding the lengths of vectors
  - Rotating vectors
  - Converting vectors between different coordinate systems

Note that unlike in many other geometry packages where vectors are used as a
general-purpose data type, `elm-geometry` has separate data types for vectors,
directions and points. In most code it is actually more common to use `Point2d`
and `Direction2d` than `Vector2d`, and much code can avoid working directly with
`Vector2d` values at all!

@docs Vector2d


# Constants

@docs zero

Although there are no predefined constants for the vectors with components
(1,&nbsp;0) and (0,&nbsp;1), in most cases you will actually want their
`Direction2d` versions [`Direction2d.x`](Direction2d#x) and [`Direction2d.y`](Direction2d#y).


# Constructors

@docs fromComponents, fromComponentsIn, fromPolarComponents, fromPolarComponentsIn, from, withLength, perpendicularTo, interpolateFrom


# Interop

These functions are useful for interoperability with other Elm code that uses
plain `Float` tuples or records to represent vectors. The resulting `Vector2d`
values will have [unitless](https://package.elm-lang.org/packages/ianmackenzie/elm-units/latest/Quantity#unitless-quantities)
components.

@docs fromTuple, toTuple, fromRecord, toRecord


# Unit conversion

@docs at, at_


# Rates of change

@docs per, for


# Properties

@docs xComponent, yComponent, componentIn, polarComponents, length, direction, lengthAndDirection


# Comparison

@docs equalWithin, lexicographicComparison


# Arithmetic

@docs plus, minus, dot, cross


# Transformations

Note that for `mirrorAcross` and `projectOnto`, only the direction of the axis
affects the result, since vectors are position-independent. Think of
mirroring/projecting a vector across/onto an axis as moving the vector so its
tail is on the axis, then mirroring/projecting its tip across/onto the axis.

@docs reverse, normalize, scaleBy, rotateBy, rotateClockwise, rotateCounterclockwise, mirrorAcross, projectionIn, projectOnto


# Coordinate conversions

Like other transformations, coordinate conversions of vectors depend only on the
orientations of the relevant frames, not the positions of their origin points.

For the examples, assume the following frame has been defined:

    rotatedFrame =
        Frame2d.atOrigin |> Frame2d.rotateBy (degrees 30)

@docs relativeTo, placeIn

-}

import Angle exposing (Angle)
import Bootstrap.Axis2d as Axis2d
import Bootstrap.Direction2d as Direction2d
import Bootstrap.Frame2d as Frame2d
import Bootstrap.Point2d as Point2d
import Geometry.Types as Types exposing (Axis2d, Direction2d, Frame2d, Point2d)
import Quantity exposing (Product, Quantity, Rate, Squared, Unitless)
import Quantity.Extra as Quantity


{-| -}
type alias Vector2d units coordinates =
    Types.Vector2d units coordinates


{-| The zero vector.

    Vector2d.zero
    --> Vector2d.fromComponents ( 0, 0 )

-}
zero : Vector2d units coordinates
zero =
    fromComponents Quantity.zero Quantity.zero


{-| Construct a vector from its X and Y components.

    vector =
        Vector2d.fromComponents ( 2, 3 )

-}
fromComponents : Quantity Float units -> Quantity Float units -> Vector2d units coordinates
fromComponents x y =
    Types.Vector2d ( x, y )


{-| Construct a vector given its local components within a particular frame:

    rotatedFrame =
        Frame2d.atOrigin
            |> Frame2d.rotateBy (Angle.degrees 45)

    Vector2d.fromComponentsIn rotatedFrame
        ( Length.meters 2
        , Length.meters 0
        )
    --> Vector2d.fromComponents
    -->     ( Length.meters 1.4142
    -->     , Length.meters 1.4142
    -->     )

-}
fromComponentsIn : Frame2d units globalCoordinates localCoordinates -> Quantity Float units -> Quantity Float units -> Vector2d units globalCoordinates
fromComponentsIn frame x y =
    let
        x1 =
            Direction2d.xComponent (Frame2d.xDirection frame)

        y1 =
            Direction2d.yComponent (Frame2d.xDirection frame)

        x2 =
            Direction2d.xComponent (Frame2d.yDirection frame)

        y2 =
            Direction2d.yComponent (Frame2d.yDirection frame)
    in
    fromComponents
        (Quantity.aXbY x1 x x2 y)
        (Quantity.aXbY y1 x y2 y)


{-| Construct a vector from a length and angle. The angle is measured
counterclockwise from the positive X direction.

    Vector2d.fromPolarComponents ( 2, degrees 135 )
    -->Vector2d.fromComponents ( -1.4142, 1.4142 )

-}
fromPolarComponents : Quantity Float units -> Angle -> Vector2d units coordinates
fromPolarComponents givenRadius givenAngle =
    fromComponents
        (Quantity.rCosTheta givenRadius givenAngle)
        (Quantity.rSinTheta givenRadius givenAngle)


{-| Construct a vector given its local polar components within a particular
frame:

    rotatedFrame =
        Frame2d.atOrigin
            |> Frame2d.rotateBy (Angle.degrees 45)

    Vector2d.fromPolarComponentsIn rotatedFrame
        ( Length.meters 1
        , Angle.degrees 0
        )
    --> Vector2d.fromComponents
    -->     ( Length.meters 0.7071
    -->     , Length.meters 0.7071
    -->     )

-}
fromPolarComponentsIn : Frame2d units globalCoordinates localCoordinates -> Quantity Float units -> Angle -> Vector2d units globalCoordinates
fromPolarComponentsIn frame r theta =
    fromComponentsIn frame
        (Quantity.rCosTheta r theta)
        (Quantity.rSinTheta r theta)


{-| Construct a vector from the first given point to the second.

    startPoint =
        Point2d.fromCoordinates ( 1, 1 )

    endPoint =
        Point2d.fromCoordinates ( 4, 5 )

    Vector2d.from startPoint endPoint
    --> Vector2d.fromComponents ( 3, 4 )

-}
from : Point2d units coordinates -> Point2d units coordinates -> Vector2d units coordinates
from firstPoint secondPoint =
    let
        x1 =
            Point2d.xCoordinate firstPoint

        y1 =
            Point2d.yCoordinate firstPoint

        x2 =
            Point2d.xCoordinate secondPoint

        y2 =
            Point2d.yCoordinate secondPoint
    in
    fromComponents
        (x2 |> Quantity.minus x1)
        (y2 |> Quantity.minus y1)


{-| Construct a vector with the given length in the given direction.

    Vector2d.withLength 5 Direction2d.y
    --> Vector2d.fromComponents ( 0, 5 )

-}
withLength : Quantity Float units -> Direction2d coordinates -> Vector2d units coordinates
withLength givenLength givenDirection =
    let
        dx =
            Direction2d.xComponent givenDirection

        dy =
            Direction2d.yComponent givenDirection
    in
    fromComponents
        (Quantity.multiplyBy dx givenLength)
        (Quantity.multiplyBy dy givenLength)


{-| Construct a vector perpendicular to the given vector, by rotating the given
vector 90 degrees counterclockwise. The constructed vector will have the same
length as the given vector. Alias for `Vector2d.rotateCounterclockwise`.

    Vector2d.perpendicularTo
        (Vector2d.fromComponents ( 1, 0 ))
    --> Vector2d.fromComponents ( 0, 1 )

    Vector2d.perpendicularTo
        (Vector2d.fromComponents ( 0, 2 ))
    --> Vector2d.fromComponents ( -2, 0 )

    Vector2d.perpendicularTo
        (Vector2d.fromComponents ( 3, 1 ))
    --> Vector2d.fromComponents ( -1, 3 )

    Vector2d.perpendicularTo Vector2d.zero
    --> Vector2d.zero

-}
perpendicularTo : Vector2d units coordinates -> Vector2d units coordinates
perpendicularTo givenVector =
    rotateCounterclockwise givenVector


{-| Construct a vector by interpolating from the first given vector to the
second, based on a parameter that ranges from zero to one.

    startVector =
        Vector2d.zero

    endVector =
        Vector2d.fromComponents ( 8, 12 )

    Vector2d.interpolateFrom startVector endVector 0.25
    --> Vector2d.fromComponents ( 2, 3 )

Partial application may be useful:

    interpolatedVector : Float -> Vector2d
    interpolatedVector =
        Vector2d.interpolateFrom startVector endVector

    List.map interpolatedVector [ 0, 0.5, 1 ]
    --> [ Vector2d.fromComponents ( 0, 0 )
    --> , Vector2d.fromComponents ( 4, 6 )
    --> , Vector2d.fromComponents ( 8, 12 )
    --> ]

You can pass values less than zero or greater than one to extrapolate:

    interpolatedVector -0.5
    --> Vector2d.fromComponents ( -4, -6 )

    interpolatedVector 1.25
    --> Vector2d.fromComponents ( 10, 15 )

-}
interpolateFrom : Vector2d units coordinates -> Vector2d units coordinates -> Float -> Vector2d units coordinates
interpolateFrom firstVector secondVector givenParameter =
    let
        ( x1, y1 ) =
            components firstVector

        ( x2, y2 ) =
            components secondVector
    in
    fromComponents
        (Quantity.interpolateFrom x1 x2 givenParameter)
        (Quantity.interpolateFrom y1 y2 givenParameter)


{-| Construct a `Vector2d` from a tuple of `Float` values, by specifying what units those values are
in.

    Vector2d.fromTuple Length.meters ( 2, 3 )
    --> Vector2d.fromComponents
    -->     (Length.meters 2)
    -->     (Length.meters 3)

-}
fromTuple : (Float -> Quantity Float units) -> ( Float, Float ) -> Vector2d units coordinates
fromTuple toQuantity ( x, y ) =
    fromComponents (toQuantity x) (toQuantity y)


{-| Convert a `Vector2d` to a tuple of `Float` values, by specifying what units you want the result
to be in.

    vector =
        Vector2d.fromComponents
            (Length.feet 2)
            (Length.feet 3)

    Vector2d.toTuple Length.inInches vector
    --> ( 24, 36 )

-}
toTuple : (Quantity Float units -> Float) -> Vector2d units coordinates -> ( Float, Float )
toTuple fromQuantity vector =
    ( fromQuantity (xComponent vector)
    , fromQuantity (yComponent vector)
    )


{-| Construct a `Vector2d` from a record with `Float` fields, by specifying what units those fields
are in.

    Vector2d.fromRecord Length.inches { x = 24, y = 36 }
    --> Vector2d.fromComponents
    -->     (Length.feet 2)
    -->     (Length.feet 3)

-}
fromRecord : (Float -> Quantity Float units) -> { x : Float, y : Float } -> Vector2d units coordinates
fromRecord toQuantity { x, y } =
    fromComponents (toQuantity x) (toQuantity y)


{-| Convert a `Vector2d` to a record with `Float` fields, by specifying what units you want the
result to be in.

    vector =
        Vector2d.fromComponents
            (Length.meters 2)
            (Length.meters 3)

    Vector2d.toRecord Length.inCentimeters vector
    --> { x = 200, y = 300 }

-}
toRecord : (Quantity Float units -> Float) -> Vector2d units coordinates -> { x : Float, y : Float }
toRecord fromQuantity vector =
    { x = fromQuantity (xComponent vector)
    , y = fromQuantity (yComponent vector)
    }


{-| Convert a vector from one units type to another, by providing a conversion factor given as a
rate of change of destination units with respect to source units.

    worldVector =
        Vector2d.fromComponents
            ( Length.meters 2
            , Length.meters 3
            )

    resolution : Quantity Float (Rate Pixels Meters)
    resolution =
        Pixels.pixels 100 |> Quantity.per (Length.meters 1)

    worldVector |> Vector2d.at resolution
    --> Vector2d.fromComponents
    -->     ( Pixels.pixels 200
    -->     , Pixels.pixels 300
    -->     )

-}
at : Quantity Float (Rate destinationUnits sourceUnits) -> Vector2d sourceUnits coordinates -> Vector2d destinationUnits coordinates
at rate vector =
    let
        ( x, y ) =
            components vector
    in
    fromComponents (Quantity.at rate x) (Quantity.at rate y)


{-| Convert a vector from one units type to another, by providing an 'inverse' conversion factor
given as a rate of change of source units with respect to destination units.

    screenVector =
        Vector2d.fromComponents
            ( Pixels.pixels 200
            , Pixels.pixels 300
            )

    resolution : Quantity Float (Rate Pixels Meters)
    resolution =
        Pixels.pixels 50 |> Quantity.per (Length.meters 1)

    screenVector |> Vector2d.at_ resolution
    --> Vector2d.fromComponents
    -->     ( Length.meters 4
    -->     , Length.meters 6
    -->     )

-}
at_ : Quantity Float (Rate sourceUnits destinationUnits) -> Vector2d sourceUnits coordinates -> Vector2d destinationUnits coordinates
at_ rate vector =
    let
        ( x, y ) =
            components vector
    in
    fromComponents (Quantity.at_ rate x) (Quantity.at_ rate y)


{-| Construct a vector representing a rate of change such as a speed:

    displacement =
        Vector2d.fromComponents
            ( Length.meters 6
            , Length.meters 8
            )

    velocity =
        displacement |> Vector2d.per (Duration.seconds 2)

    -- Get the magnitude of the velocity (the speed)
    Vector2d.length velocity
    --> Speed.metersPerSecond 5

-}
per : Quantity Float independentUnits -> Vector2d dependentUnits coordinates -> Vector2d (Rate dependentUnits independentUnits) coordinates
per independentQuantity vector =
    let
        ( x, y ) =
            components vector
    in
    fromComponents (Quantity.per independentQuantity x) (Quantity.per independentQuantity y)


{-| Multiply a rate of change vector by an independent quantity to get a total vector. For example,
multiply a velocity by a duration to get a total displacement:

    velocity =
        Vector2d.fromComponents
            ( Pixels.pixelsPerSecond 200
            , Pixels.pixelsPerSecond 50
            )

    velocity |> Vector2d.for (Duration.seconds 0.1)
    --> Vector2d.fromComponents
    -->     ( Pixels.pixels 20
    -->     , Pixels.pixels 5
    -->     )

-}
for : Quantity Float independentUnits -> Vector2d (Rate dependentUnits independentUnits) coordinates -> Vector2d dependentUnits coordinates
for independentQuantity vector =
    let
        ( x, y ) =
            components vector
    in
    fromComponents (Quantity.for independentQuantity x) (Quantity.for independentQuantity y)


{-| Extract the components of a vector.

    Vector2d.components (Vector2d.fromComponents ( 2, 3 ))
    --> ( 2, 3 )

This combined with Elm's built-in tuple destructuring provides a convenient way
to extract both the X and Y components of a vector in one line of code:

    ( x, y ) =
        Vector2d.components vector

-}
components : Vector2d units coordinates -> ( Quantity Float units, Quantity Float units )
components (Types.Vector2d vectorComponents) =
    vectorComponents


{-| Find the components of a vector in a given frame;

    Vector2d.componentsIn frame vector

is equivalent to

    ( Vector2d.componentIn (Frame2d.xDirection frame) vector
    , Vector2d.componentIn (Frame2d.yDirection frame) vector
    )

-}
componentsIn : Frame2d units globalCoordinates localCoordinates -> Vector2d units globalCoordinates -> ( Quantity Float units, Quantity Float units )
componentsIn frame vector =
    ( vector |> componentIn (Frame2d.xDirection frame)
    , vector |> componentIn (Frame2d.yDirection frame)
    )


{-| Get the X component of a vector.

    Vector2d.xComponent (Vector2d.fromComponents ( 2, 3 ))
    --> 2

-}
xComponent : Vector2d units coordinates -> Quantity Float units
xComponent (Types.Vector2d ( x, _ )) =
    x


{-| Get the Y component of a vector.

    Vector2d.yComponent (Vector2d.fromComponents ( 2, 3 ))
    --> 3

-}
yComponent : Vector2d units coordinates -> Quantity Float units
yComponent (Types.Vector2d ( _, y )) =
    y


{-| Find the component of a vector in an arbitrary direction, for example

    forwardSpeed =
        Vector2d.componentIn forwardDirection velocity

This is more general and flexible than using `xComponent` or `yComponent`, both
of which can be expressed in terms of `componentIn`; for example,

    Vector2d.xComponent vector

is equivalent to

    Vector2d.componentIn Direction2d.x vector

-}
componentIn : Direction2d coordinates -> Vector2d units coordinates -> Quantity Float units
componentIn givenDirection givenVector =
    let
        dx =
            Direction2d.xComponent givenDirection

        dy =
            Direction2d.yComponent givenDirection

        ( vx, vy ) =
            components givenVector
    in
    Quantity.aXbY dx vx dy vy


{-| Get the polar components (length, polar angle) of a vector.

    Vector2d.polarComponents
        (Vector2d.fromComponents ( 1, 1 ))
    --> ( 1.4142, degrees 45 )

-}
polarComponents : Vector2d units coordinates -> ( Quantity Float units, Angle )
polarComponents givenVector =
    let
        ( x, y ) =
            components givenVector
    in
    ( length givenVector, Angle.atan2 y x )


{-| Compare two vectors within a tolerance. Returns true if the difference
between the two given vectors has magnitude less than the given tolerance.

    firstVector =
        Vector2d.fromComponents ( 1, 2 )

    secondVector =
        Vector2d.fromComponents ( 0.9999, 2.0002 )

    Vector2d.equalWithin 1e-3 firstVector secondVector
    --> True

    Vector2d.equalWithin 1e-6 firstVector secondVector
    --> False

-}
equalWithin : Quantity Float units -> Vector2d units coordinates -> Vector2d units coordinates -> Bool
equalWithin givenTolerance firstVector secondVector =
    length (secondVector |> minus firstVector) |> Quantity.lessThanOrEqualTo givenTolerance


{-| Compare two `Vector2d` values lexicographically: first by X component, then
by Y. Can be used to provide a sort order for `Vector2d` values.
-}
lexicographicComparison : Vector2d units coordinates -> Vector2d units coordinates -> Order
lexicographicComparison firstVector secondVector =
    let
        ( x1, y1 ) =
            components firstVector

        ( x2, y2 ) =
            components secondVector
    in
    if x1 /= x2 then
        Quantity.compare x1 x2

    else
        Quantity.compare y1 y2


{-| Get the length (magnitude) of a vector.

    Vector2d.length (Vector2d.fromComponents ( 3, 4 ))
    --> 5

-}
length : Vector2d units coordinates -> Quantity Float units
length givenVector =
    let
        ( vx, vy ) =
            components givenVector

        largestComponent =
            Quantity.max (Quantity.abs vx) (Quantity.abs vy)
    in
    if largestComponent == Quantity.zero then
        Quantity.zero

    else
        let
            scaledX =
                Quantity.ratio vx largestComponent

            scaledY =
                Quantity.ratio vy largestComponent

            scaledLength =
                sqrt (scaledX * scaledX + scaledY * scaledY)
        in
        Quantity.multiplyBy scaledLength largestComponent


{-| Attempt to find the direction of a vector. In the case of a zero vector,
return `Nothing`.

    Vector2d.direction (Vector2d.fromComponents ( 3, 3 ))
    --> Just (Direction2d.fromAngle (degrees 45))

    Vector2d.direction Vector2d.zero
    --> Nothing

-}
direction : Vector2d units coordinates -> Maybe (Direction2d coordinates)
direction givenVector =
    let
        ( vx, vy ) =
            components givenVector

        largestComponent =
            Quantity.max (Quantity.abs vx) (Quantity.abs vy)
    in
    if largestComponent == Quantity.zero then
        Nothing

    else
        let
            scaledX =
                Quantity.ratio vx largestComponent

            scaledY =
                Quantity.ratio vy largestComponent

            scaledLength =
                sqrt (scaledX * scaledX + scaledY * scaledY)
        in
        Just (Direction2d.unsafeFromComponents (scaledX / scaledLength) (scaledY / scaledLength))


{-| Attempt to find the length and direction of a vector. In the case of a zero
vector, returns `Nothing`.

    vector =
        Vector2d.fromComponents ( 1, 1 )

    Vector2d.lengthAndDirection vector
    --> Just
    -->     ( 1.4142
    -->     , Direction2d.fromAngle (degrees 45)
    -->     )

    Vector2d.lengthAndDirection Vector2d.zero
    --> Nothing

-}
lengthAndDirection : Vector2d units coordinates -> Maybe ( Quantity Float units, Direction2d coordinates )
lengthAndDirection givenVector =
    let
        ( vx, vy ) =
            components givenVector

        largestComponent =
            Quantity.max (Quantity.abs vx) (Quantity.abs vy)
    in
    if largestComponent == Quantity.zero then
        Nothing

    else
        let
            scaledX =
                Quantity.ratio vx largestComponent

            scaledY =
                Quantity.ratio vy largestComponent

            scaledLength =
                sqrt (scaledX * scaledX + scaledY * scaledY)

            computedLength =
                Quantity.multiplyBy scaledLength largestComponent

            computedDirection =
                Direction2d.unsafeFromComponents (scaledX / scaledLength) (scaledY / scaledLength)
        in
        Just ( computedLength, computedDirection )


{-| Normalize a vector to have a length of one. Zero vectors are left as-is.

    vector =
        Vector2d.fromComponents ( 3, 4 )

    Vector2d.normalize vector
    --> Vector2d.fromComponents ( 0.6, 0.8 )

    Vector2d.normalize Vector2d.zero
    --> Vector2d.zero

**Warning**: `Vector2d.direction` is safer since it forces you to explicitly
consider the case where the given vector is zero. `Vector2d.normalize` is
primarily useful for cases like generating WebGL meshes, where defaulting to a
zero vector for degenerate cases is acceptable, and the overhead of something
like

    Vector2d.direction vector
        |> Maybe.map Direction2d.toVector
        |> Maybe.withDefault Vector2d.zero

(which is functionally equivalent to `Vector2d.normalize vector`) is too high.

-}
normalize : Vector2d units coordinates -> Vector2d Unitless coordinates
normalize givenVector =
    let
        ( vx, vy ) =
            components givenVector

        largestComponent =
            Quantity.max (Quantity.abs vx) (Quantity.abs vy)
    in
    if largestComponent == Quantity.zero then
        zero

    else
        let
            scaledX =
                Quantity.ratio vx largestComponent

            scaledY =
                Quantity.ratio vy largestComponent

            scaledLength =
                sqrt (scaledX * scaledX + scaledY * scaledY)
        in
        fromComponents
            (Quantity.float (scaledX / scaledLength))
            (Quantity.float (scaledY / scaledLength))


{-| Find the sum of two vectors.

    firstVector =
        Vector2d.fromComponents ( 1, 2 )

    secondVector =
        Vector2d.fromComponents ( 3, 4 )

    Vector2d.sum firstVector secondVector
    --> Vector2d.fromComponents ( 4, 6 )

-}
plus : Vector2d units coordinates -> Vector2d units coordinates -> Vector2d units coordinates
plus secondVector firstVector =
    let
        ( x1, y1 ) =
            components firstVector

        ( x2, y2 ) =
            components secondVector
    in
    fromComponents
        (x1 |> Quantity.plus x2)
        (y1 |> Quantity.plus y2)


{-| Find the difference between two vectors (the first vector minus the second).

    firstVector =
        Vector2d.fromComponents ( 5, 6 )

    secondVector =
        Vector2d.fromComponents ( 1, 3 )

    Vector2d.difference firstVector secondVector
    --> Vector2d.fromComponents ( 4, 3 )

-}
minus : Vector2d units coordinates -> Vector2d units coordinates -> Vector2d units coordinates
minus secondVector firstVector =
    let
        ( x1, y1 ) =
            components firstVector

        ( x2, y2 ) =
            components secondVector
    in
    fromComponents
        (x1 |> Quantity.minus x2)
        (y1 |> Quantity.minus y2)


{-| Find the dot product of two vectors.

    firstVector =
        Vector2d.fromComponents
            ( Length.meters 1
            , Length.meters 2
            )

    secondVector =
        Vector2d.fromComponents
            ( Length.meters 3
            , Length.meters 4
            )

    firstVector |> Vector2d.dot secondVector
    --> Area.squareMeters 11

-}
dot : Vector2d units2 coordinates -> Vector2d units1 coordinates -> Quantity Float (Product units1 units2)
dot secondVector firstVector =
    let
        ( x1, y1 ) =
            components firstVector

        ( x2, y2 ) =
            components secondVector
    in
    (x1 |> Quantity.times x2) |> Quantity.plus (y1 |> Quantity.times y2)


{-| Find the scalar 'cross product' of two vectors in 2D. This is useful in many
of the same ways as the 3D cross product:

  - Its length is equal to the product of the lengths of the two given vectors
    and the sine of the angle between them, so it can be used as a metric to
    determine if two vectors are nearly parallel.
  - The sign of the result indicates the direction of rotation from the first
    vector to the second (positive indicates a counterclockwise rotation and
    negative indicates a clockwise rotation), similar to how the direction of
    the 3D cross product indicates the direction of rotation.

Note the argument order - `v1 x v2` would be written as

    v1 |> Vector2d.cross v2

which is the same as

    Vector2d.cross v2 v1

but the _opposite_ of

    Vector2d.cross v1 v2

Some examples:

    firstVector =
        Vector2d.fromComponents
            ( Length.feet 2
            , Length.feet 0
            )

    secondVector =
        Vector2d.fromComponents
            ( Length.feet 0
            , Length.feet 3
            )

    firstVector |> Vector2d.cross secondVector
    --> Area.squareFeet 6

    secondVector |> Vector2d.cross firstVector
    --> Area.squareFeet -6

    firstVector |> Vector2d.cross firstVector
    --> Area.squareFeet 0

-}
cross : Vector2d units2 coordinates -> Vector2d units1 coordinates -> Quantity Float (Product units1 units2)
cross secondVector firstVector =
    let
        ( x1, y1 ) =
            components firstVector

        ( x2, y2 ) =
            components secondVector
    in
    (x1 |> Quantity.times y2) |> Quantity.minus (y1 |> Quantity.times x2)


{-| Reverse the direction of a vector, negating its components.

    Vector2d.reverse (Vector2d.fromComponents ( -1, 2 ))
    --> Vector2d.fromComponents ( 1, -2 )

(This could have been called `negate`, but `reverse` is more consistent with
the naming used in other modules.)

-}
reverse : Vector2d units coordinates -> Vector2d units coordinates
reverse givenVector =
    let
        ( x, y ) =
            components givenVector
    in
    fromComponents (Quantity.negate x) (Quantity.negate y)


{-| Scale the length of a vector by a given scale.

    Vector2d.scaleBy 3 (Vector2d.fromComponents ( 1, 2 ))
    --> Vector2d.fromComponents ( 3, 6 )

(This could have been called `multiply` or `times`, but `scaleBy` was chosen as
a more geometrically meaningful name and to be consistent with the `scaleAbout`
name used in other modules.)

-}
scaleBy : Float -> Vector2d units coordinates -> Vector2d units coordinates
scaleBy givenScale givenVector =
    let
        ( x, y ) =
            components givenVector
    in
    fromComponents
        (Quantity.multiplyBy givenScale x)
        (Quantity.multiplyBy givenScale y)


{-| Rotate a vector counterclockwise by a given angle (in radians).

    Vector2d.fromComponents ( 1, 1 )
        |> Vector2d.rotateBy (degrees 45)
    --> Vector2d.fromComponents ( 0, 1.4142 )

    Vector2d.fromComponents ( 1, 0 )
        |> Vector2d.rotateBy pi
    --> Vector2d.fromComponents ( -1, 0 )

-}
rotateBy : Angle -> Vector2d units coordinates -> Vector2d units coordinates
rotateBy givenAngle givenVector =
    let
        c =
            Angle.cos givenAngle

        s =
            Angle.sin givenAngle

        ( x, y ) =
            components givenVector
    in
    fromComponents
        (Quantity.aXbY c x -s y)
        (Quantity.aXbY s x c y)


{-| Rotate the given vector 90 degrees counterclockwise;

    Vector2d.rotateCounterclockwise vector

is equivalent to

    Vector2d.rotateBy (degrees 90) vector

but is more efficient.

-}
rotateCounterclockwise : Vector2d units coordinates -> Vector2d units coordinates
rotateCounterclockwise givenVector =
    let
        ( x, y ) =
            components givenVector
    in
    fromComponents (Quantity.negate y) x


{-| Rotate the given vector 90 degrees clockwise;

    Vector2d.rotateClockwise vector

is equivalent to

    Vector2d.rotateBy (degrees -90) vector

but is more efficient.

-}
rotateClockwise : Vector2d units coordinates -> Vector2d units coordinates
rotateClockwise givenVector =
    let
        ( x, y ) =
            components givenVector
    in
    fromComponents y (Quantity.negate x)


{-| Mirror a vector across a given axis.

    vector =
        Vector2d.fromComponents ( 2, 3 )

    Vector2d.mirrorAcross Axis2d.y vector
    --> Vector2d.fromComponents ( -2, 3 )

The position of the axis doesn't matter, only its orientation:

    horizontalAxis =
        Axis2d.withDirection Direction2d.x
            (Point2d.fromCoordinates ( 100, 200 ))

    Vector2d.mirrorAcross horizontalAxis vector
    --> Vector2d.fromComponents ( 2, -3 )

-}
mirrorAcross : Axis2d axisUnits coordinates -> Vector2d units coordinates -> Vector2d units coordinates
mirrorAcross givenAxis givenVector =
    let
        dx =
            Direction2d.xComponent (Axis2d.direction givenAxis)

        dy =
            Direction2d.yComponent (Axis2d.direction givenAxis)

        yy =
            1 - 2 * dy * dy

        xy =
            2 * dx * dy

        xx =
            1 - 2 * dx * dx

        ( vx, vy ) =
            components givenVector
    in
    fromComponents
        (Quantity.aXbY yy vx xy vy)
        (Quantity.aXbY xy vx xx vy)


{-| Find the projection of a vector in a particular direction. Conceptually,
this means splitting the original vector into a portion parallel to the given
direction and a portion perpendicular to it, then returning the parallel
portion.

    vector =
        Vector2d.fromComponents ( 2, 3 )

    Vector2d.projectionIn Direction2d.x vector
    --> Vector2d.fromComponents ( 2, 0 )

    Vector2d.projectionIn Direction2d.y vector
    --> Vector2d.fromComponents ( 0, 3 )

-}
projectionIn : Direction2d coordinates -> Vector2d units coordinates -> Vector2d units coordinates
projectionIn givenDirection givenVector =
    givenDirection |> withLength (givenVector |> componentIn givenDirection)


{-| Project a vector onto an axis.

    Vector2d.projectOnto Axis2d.y
        (Vector2d.fromComponents ( 3, 4 ))
    --> Vector2d.fromComponents ( 0, 4 )

    Vector2d.projectOnto Axis2d.x
        (Vector2d.fromComponents ( -1, 2 ))
    --> Vector2d.fromComponents ( -1, 0 )

This is equivalent to finding the projection in the axis' direction.

-}
projectOnto : Axis2d units coordinates -> Vector2d units coordinates -> Vector2d units coordinates
projectOnto givenAxis givenVector =
    projectionIn (Axis2d.direction givenAxis) givenVector


{-| Take a vector defined in global coordinates, and return it expressed in
local coordinates relative to a given reference frame.

    Vector2d.fromComponents ( 2, 0 )
        |> Vector2d.relativeTo rotatedFrame
    --> Vector2d.fromComponents ( 1.732, -1 )

-}
relativeTo : Frame2d frameUnits globalCoordinates localCoordinates -> Vector2d units globalCoordinates -> Vector2d units localCoordinates
relativeTo givenFrame givenVector =
    fromComponents
        (componentIn (Frame2d.xDirection givenFrame) givenVector)
        (componentIn (Frame2d.yDirection givenFrame) givenVector)


{-| Take a vector defined in local coordinates relative to a given reference
frame, and return that vector expressed in global coordinates.

    Vector2d.fromComponents ( 2, 0 )
        |> Vector2d.placeIn rotatedFrame
    --> Vector2d.fromComponents ( 1.732, 1 )

-}
placeIn : Frame2d frameUnits globalCoordinates localCoordinates -> Vector2d units localCoordinates -> Vector2d units globalCoordinates
placeIn givenFrame givenVector =
    let
        x1 =
            Direction2d.xComponent (Frame2d.xDirection givenFrame)

        y1 =
            Direction2d.yComponent (Frame2d.xDirection givenFrame)

        x2 =
            Direction2d.xComponent (Frame2d.yDirection givenFrame)

        y2 =
            Direction2d.yComponent (Frame2d.yDirection givenFrame)

        ( x, y ) =
            components givenVector
    in
    fromComponents
        (Quantity.aXbY x1 x x2 y)
        (Quantity.aXbY y1 x y2 y)
