//
//  CGGeometry+HHImageCropper.swift
//  BoxAvatar
//
//  Created by Haijian Huo on 8/13/17.
//  Copyright © 2017 Haijian Huo. All rights reserved.
//

import Foundation
import CoreGraphics

#if CGFLOAT_IS_DOUBLE
    let HH_EPSILON  = DBL_EPSILON
    let HH_MIN = DBL_MIN
#else
    let HH_EPSILON = CGFloat.ulpOfOne
    let HH_MIN = CGFloat.leastNormalMagnitude
#endif


// Line segments.

struct HHLineSegment {
    var start: CGPoint
    var end: CGPoint
}

let HHPointNull = CGPoint(x: CGFloat.infinity, y: CGFloat.infinity)

func HHRectCenterPoint(rect: CGRect) -> CGPoint
{
    return CGPoint(x: rect.minX + rect.width / 2,
                   y: rect.minY + rect.height / 2)
}

func HHRectScaleAroundPoint(rect: CGRect, point: CGPoint, sx: CGFloat, sy: CGFloat) -> CGRect
{
    var translationTransform: CGAffineTransform
    var scaleTransform: CGAffineTransform
    
    translationTransform = CGAffineTransform(translationX: -point.x, y: -point.y)
    
    var rect = rect.applying(translationTransform)
    
    scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
    
    rect = rect.applying(scaleTransform)
    
    translationTransform = CGAffineTransform(translationX: point.x, y: point.y)
    rect = rect.applying(translationTransform)
    return rect
}

func HHPointIsNull(point: CGPoint) -> Bool
{
    return point.equalTo(HHPointNull)
}

func HHPointRotateAroundPoint(point: CGPoint, pivot: CGPoint, angle: CGFloat) -> CGPoint
{
    var translationTransform: CGAffineTransform
    var rotationTransform: CGAffineTransform
    
    translationTransform = CGAffineTransform(translationX: -pivot.x, y: -pivot.y)
    
    var point = point.applying(translationTransform)
    rotationTransform = CGAffineTransform(rotationAngle: angle)
    point = point.applying(rotationTransform)
    translationTransform = CGAffineTransform(translationX: pivot.x, y: pivot.y)
    point = point.applying(translationTransform)
    return point
}

func HHPointDistance(p1: CGPoint, p2: CGPoint) -> CGFloat
{
    let dx = p1.x - p2.x
    let dy = p1.y - p2.y
    return sqrt(pow(dx, 2) + pow(dy, 2))
}

func HHLineSegmentMake(start: CGPoint, end: CGPoint) -> HHLineSegment
{
    return HHLineSegment(start: start, end: end)
}

func HHLineSegmentRotateAroundPoint(line: HHLineSegment, pivot: CGPoint,  angle: CGFloat) -> HHLineSegment
{
    return HHLineSegmentMake(start: HHPointRotateAroundPoint(point: line.start, pivot: pivot, angle: angle), end: HHPointRotateAroundPoint(point: line.end, pivot: pivot, angle: angle))
}

/*
 Equations of line segments:
 
 pA = ls1.start + uA * (ls1.end - ls1.start)
 pB = ls2.start + uB * (ls2.end - ls2.start)
 
 In the case when `pA` is equal `pB` we have:
 
 x1 + uA * (x2 - x1) = x3 + uB * (x4 - x3)
 y1 + uA * (y2 - y1) = y3 + uB * (y4 - y3)
 
 uA = (x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3) / (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
 uB = (x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3) / (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
 
 numeratorA = (x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)
 denominatorA = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
 
 numeratorA = (x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)
 denominatorB = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
 
 [1] Denominators are equal.
 [2] If numerators and denominator are zero, then the line segments are coincident. The point of intersection is the midpoint of the line segment.
 
 x = (x1 + x2) * 0.5
 y = (y1 + y2) * 0.5
 
 or
 
 x = (x3 + x4) * 0.5
 y = (y3 + y4) * 0.5
 
 [3] If denominator is zero, then the line segments are parallel. There is no point of intersection.
 [4] If `uA` and `uB` is included into the interval [0, 1], then the line segments intersects in the point (x, y).
 
 x = x1 + uA * (x2 - x1)
 y = y1 + uA * (y2 - y1)
 
 or
 
 x = x3 + uB * (x4 - x3)
 y = y3 + uB * (y4 - y3)
 */
func HHLineSegmentIntersection(ls1: HHLineSegment, ls2: HHLineSegment) ->CGPoint
{
    let x1 = ls1.start.x
    let y1 = ls1.start.y
    let x2 = ls1.end.x
    let y2 = ls1.end.y
    let x3 = ls2.start.x
    let y3 = ls2.start.y
    let x4 = ls2.end.x
    let y4 = ls2.end.y
    
    let numeratorA = (x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)
    let numeratorB = (x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)
    let denominator = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
    
    // Check the coincidence.
    if (fabs(numeratorA) < HH_EPSILON && fabs(numeratorB) < HH_EPSILON && fabs(denominator) < HH_EPSILON) {
        return CGPoint(x: (x1 + x2) * 0.5, y: (y1 + y2) * 0.5)
    }
    
    // Check the parallelism.
    if (fabs(denominator) < HH_EPSILON) {
        return HHPointNull
    }
    
    // Check the intersection.
    let uA = numeratorA / denominator
    let uB = numeratorB / denominator
    if (uA < 0 || uA > 1 || uB < 0 || uB > 1) {
        return HHPointNull
    }
    
    return CGPoint(x: x1 + uA * (x2 - x1), y: y1 + uA * (y2 - y1))
}

