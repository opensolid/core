module Tests.CubicSpline3d exposing
    ( approximate
    , arcLengthMatchesAnalytical
    , bSplineReproducesSpline
    , fromEndpointsReproducesSpline
    , pointAtArcLengthIsEnd
    , pointAtZeroLengthIsStart
    )

import CubicSpline3d exposing (CubicSpline3d)
import Expect
import Fuzz
import Geometry.Expect as Expect
import Geometry.Fuzz as Fuzz
import Length exposing (Meters, meters)
import Quantity exposing (zero)
import Test exposing (Test)
import Tests.Generic.Curve3d as Curve3d
import Tests.QuadraticSpline3d
import Vector3d


fromEndpointsReproducesSpline : Test
fromEndpointsReproducesSpline =
    Test.fuzz Fuzz.cubicSpline3d
        "CubicSpline3d.fromEndpoints reproduces original spline"
        (\spline ->
            let
                startPoint =
                    CubicSpline3d.startPoint spline

                endPoint =
                    CubicSpline3d.endPoint spline

                startDerivative =
                    CubicSpline3d.startDerivative spline

                endDerivative =
                    CubicSpline3d.endDerivative spline
            in
            CubicSpline3d.fromEndpoints startPoint startDerivative endPoint endDerivative
                |> Expect.cubicSpline3d spline
        )


arcLengthMatchesAnalytical : Test
arcLengthMatchesAnalytical =
    Test.fuzz Tests.QuadraticSpline3d.curvedSpline
        "arc length matches analytical formula"
        (\quadraticSpline ->
            quadraticSpline
                |> CubicSpline3d.fromQuadraticSpline
                |> CubicSpline3d.nondegenerate
                |> Result.map
                    (CubicSpline3d.arcLengthParameterized
                        { maxError = meters 0.001 }
                        >> CubicSpline3d.arcLength
                    )
                |> Result.withDefault zero
                |> Expect.quantityWithin (meters 0.001)
                    (Tests.QuadraticSpline3d.analyticalLength quadraticSpline)
        )


pointAtZeroLengthIsStart : Test
pointAtZeroLengthIsStart =
    Test.fuzz Fuzz.cubicSpline3d
        "point along spline at zero length is start point"
        (\spline ->
            case CubicSpline3d.nondegenerate spline of
                Ok nondegenerateSpline ->
                    let
                        parameterizedSpline =
                            nondegenerateSpline
                                |> CubicSpline3d.arcLengthParameterized
                                    { maxError = meters 1.0e-3 }
                    in
                    CubicSpline3d.pointAlong parameterizedSpline (meters 0)
                        |> Expect.point3d (CubicSpline3d.startPoint spline)

                Err _ ->
                    Expect.pass
        )


pointAtArcLengthIsEnd : Test
pointAtArcLengthIsEnd =
    Test.fuzz Fuzz.cubicSpline3d
        "point along spline at arc length is end point"
        (\spline ->
            case CubicSpline3d.nondegenerate spline of
                Ok nondegenerateSpline ->
                    let
                        parameterizedSpline =
                            nondegenerateSpline
                                |> CubicSpline3d.arcLengthParameterized
                                    { maxError = meters 1.0e-3 }

                        arcLength =
                            CubicSpline3d.arcLength parameterizedSpline
                    in
                    CubicSpline3d.pointAlong parameterizedSpline arcLength
                        |> Expect.point3d (CubicSpline3d.endPoint spline)

                Err _ ->
                    Expect.pass
        )


bSplineReproducesSpline : Test
bSplineReproducesSpline =
    Test.fuzz Fuzz.cubicSpline3d
        "Can reconstruct a cubic spline with a B-spline with repeated knots"
        (\spline ->
            let
                p1 =
                    CubicSpline3d.firstControlPoint spline

                p2 =
                    CubicSpline3d.secondControlPoint spline

                p3 =
                    CubicSpline3d.thirdControlPoint spline

                p4 =
                    CubicSpline3d.fourthControlPoint spline

                bSplineSegments =
                    CubicSpline3d.bSplineSegments [ 0, 0, 0, 1, 1, 1 ]
                        [ p1, p2, p3, p4 ]
            in
            case bSplineSegments of
                [ singleSegment ] ->
                    singleSegment |> Expect.cubicSpline3d spline

                _ ->
                    Expect.fail "Expected a single B-spline segment"
        )


curveOperations : Curve3d.Operations (CubicSpline3d Meters coordinates) coordinates
curveOperations =
    { fuzzer = Fuzz.cubicSpline3d
    , pointOn = CubicSpline3d.pointOn
    , firstDerivative = CubicSpline3d.firstDerivative
    , scaleAbout = CubicSpline3d.scaleAbout
    , translateBy = CubicSpline3d.translateBy
    , rotateAround = CubicSpline3d.rotateAround
    , mirrorAcross = CubicSpline3d.mirrorAcross
    , numApproximationSegments = CubicSpline3d.numApproximationSegments
    }


approximate : Test
approximate =
    Curve3d.approximate curveOperations
