//
//  TLSpringFlowLayoutSwift.swift
//  TLSpringFlowLayoutSwift
//
//  Created by Enamel Systems on 2014/08/05.
//  Copyright (c) 2014 Enamel Systems. All rights reserved.
//

import UIKit

class TLSpringFlowLayoutSwift: UICollectionViewFlowLayout {
    /// The default resistance factor that determines the bounce of the collection. Default is 900.0f.
    let kScrollResistanceFactorDefault: CGFloat = 900.0

    /// The scrolling resistance factor determines how much bounce / resistance the collection has. A higher number is less bouncy, a lower number is more bouncy. The default is 900.0f.
    var scrollResistanceFactor: CGFloat!

    /// The dynamic animator used to animate the collection's bounce
    let dynamicAnimator: UIDynamicAnimator!

    // Needed for tiling
    var visibleIndexPathsSet: NSMutableSet
    var visibleHeaderAndFooterSet: NSMutableSet
    var latestDelta: CGFloat
    var interfaceOrientation: UIInterfaceOrientation
    
    required init(coder aDecoder: NSCoder) {
        self.visibleIndexPathsSet = NSMutableSet()
        self.visibleHeaderAndFooterSet = NSMutableSet()
        self.latestDelta = 0.0
        self.interfaceOrientation = UIApplication.sharedApplication().statusBarOrientation
        super.init(coder: aDecoder)
        self.dynamicAnimator = UIDynamicAnimator(collectionViewLayout: self)
    }
    
    override func prepareLayout() {
        super.prepareLayout()
        
        if UIApplication.sharedApplication().statusBarOrientation != self.interfaceOrientation {
            self.dynamicAnimator.removeAllBehaviors()
            self.visibleIndexPathsSet = NSMutableSet()
        }
        
        self.interfaceOrientation = UIApplication.sharedApplication().statusBarOrientation
        
        // Need to overflow our actual visible rect slightly to avoid flickering.
        let visibleRect = CGRectInset(CGRect(origin: self.collectionView.bounds.origin, size: self.collectionView.frame.size), -100, -100)

        let itemsInVisibleRectArray = super.layoutAttributesForElementsInRect(visibleRect) as [UICollectionViewLayoutAttributes]
        
        let itemsIndexPathsInVisibleRectSet = NSSet(array: itemsInVisibleRectArray.map{ $0.indexPath })
        
        // Step 1: Remove any behaviours that are no longer visible.
        let noLongerVisibleBehaviours = (self.dynamicAnimator.behaviors as [UIAttachmentBehavior]).filter {
            (behaviour: UIAttachmentBehavior) -> Bool in
            let indexPath = (behaviour.items[0] as UICollectionViewLayoutAttributes).indexPath
            return itemsIndexPathsInVisibleRectSet.containsObject(indexPath) == false
        }
        
        for behavior in noLongerVisibleBehaviours {
            self.dynamicAnimator.removeBehavior(behavior)
            let indexPath = (behavior.items[0] as UICollectionViewLayoutAttributes).indexPath
            self.visibleIndexPathsSet.removeObject(indexPath)
            self.visibleHeaderAndFooterSet.removeObject(indexPath)
        }
        
        // Step 2: Add any newly visible behaviours.
        // A "newly visible" item is one that is in the itemsInVisibleRect(Set|Array) but not in the visibleIndexPathsSet
        let newlyVisibleItems = itemsInVisibleRectArray.filter {
            (item: UICollectionViewLayoutAttributes) -> Bool in
            (item.representedElementCategory == UICollectionElementCategory.Cell ?
                self.visibleIndexPathsSet.containsObject(item.indexPath) : self.visibleHeaderAndFooterSet.containsObject(item.indexPath)) == false
        }
        
        let touchLocation = self.collectionView.panGestureRecognizer.locationInView(self.collectionView)
        
        for item in newlyVisibleItems {
            var center = item.center
            let springBehaviour = UIAttachmentBehavior(item: item, attachedToAnchor: center)
            
            springBehaviour.length = 1.0
            springBehaviour.damping = 0.8
            springBehaviour.frequency = 1.0

            // If our touchLocation is not (0,0), we'll need to adjust our item's center "in flight"
            if !CGPointEqualToPoint(CGPointZero, touchLocation) {
                if self.scrollDirection == UICollectionViewScrollDirection.Vertical {
                    let distanceFromTouch: CGFloat = abs(touchLocation.y - springBehaviour.anchorPoint.y)

                    var scrollResistance: CGFloat
                    if self.scrollResistanceFactor != nil {
                        scrollResistance = distanceFromTouch / self.scrollResistanceFactor;
                    } else {
                        scrollResistance = distanceFromTouch / kScrollResistanceFactorDefault;
                    }
                    
                    if self.latestDelta < 0 {
                        center.y += max(self.latestDelta, self.latestDelta * scrollResistance);
                    } else {
                        center.y += min(self.latestDelta, self.latestDelta * scrollResistance);
                    }

                    item.center = center
                } else {
                    let distanceFromTouch: CGFloat = abs(touchLocation.x - springBehaviour.anchorPoint.x)
                    
                    var scrollResistance: CGFloat
                    if self.scrollResistanceFactor != nil {
                        scrollResistance = distanceFromTouch / self.scrollResistanceFactor;
                    } else {
                        scrollResistance = distanceFromTouch / kScrollResistanceFactorDefault;
                    }
                    
                    if (self.latestDelta < 0) {
                        center.x += max(self.latestDelta, self.latestDelta * scrollResistance);
                    } else {
                        center.x += min(self.latestDelta, self.latestDelta * scrollResistance);
                    }
                    
                    item.center = center
                }
            }
            
            self.dynamicAnimator.addBehavior(springBehaviour)
            
            if (item.representedElementCategory == UICollectionElementCategory.Cell) {
                self.visibleIndexPathsSet.addObject(item.indexPath)
            } else {
                self.visibleHeaderAndFooterSet.addObject(item.indexPath)
            }
        }
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]! {
        return self.dynamicAnimator.itemsInRect(rect)
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath!) -> UICollectionViewLayoutAttributes! {
        let dynamicLayoutAttributes: UICollectionViewLayoutAttributes! = self.dynamicAnimator.layoutAttributesForCellAtIndexPath(indexPath)

        // Check if dynamic animator has layout attributes for a layout, otherwise use the flow layouts properties. This will prevent crashing when you add items later in a performBatchUpdates block (e.g. triggered by NSFetchedResultsController update)
        if dynamicLayoutAttributes != nil {
            return dynamicLayoutAttributes
        } else {
            return super.layoutAttributesForItemAtIndexPath(indexPath)
        }
    }
    
    // Initially return true for all of cell.
    // Usually return trur for invoking: func invalidateLayoutWithContext(_ context: UICollectionViewLayoutInvalidationContext!)
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        let scrollView = self.collectionView;
        
        var delta: CGFloat
        if self.scrollDirection == UICollectionViewScrollDirection.Vertical {
            delta = newBounds.origin.y - scrollView.bounds.origin.y;
        } else {
            delta = newBounds.origin.x - scrollView.bounds.origin.x;
        }
        
        self.latestDelta = delta;
        
        let touchLocation = self.collectionView.panGestureRecognizer.locationInView(self.collectionView)

        for springBehaviour in self.dynamicAnimator.behaviors as [UIAttachmentBehavior] {
            if self.scrollDirection == UICollectionViewScrollDirection.Vertical {
                var distanceFromTouch: CGFloat = abs(touchLocation.y - springBehaviour.anchorPoint.y)

                var scrollResistance: CGFloat
                if self.scrollResistanceFactor != nil {
                    scrollResistance = distanceFromTouch / self.scrollResistanceFactor
                } else {
                    scrollResistance = distanceFromTouch / kScrollResistanceFactorDefault;
                }
                
                let item = springBehaviour.items[0] as UICollectionViewLayoutAttributes

                var center = item.center;
                if delta < 0 {
                    center.y += max(delta, delta * scrollResistance);
                } else {
                    center.y += min(delta, delta * scrollResistance);
                }
                item.center = center;
                
                self.dynamicAnimator.updateItemUsingCurrentState(item)
            } else {
                var distanceFromTouch: CGFloat = abs(touchLocation.x - springBehaviour.anchorPoint.x)
                
                var scrollResistance: CGFloat
                if self.scrollResistanceFactor != nil {
                    scrollResistance = distanceFromTouch / self.scrollResistanceFactor
                } else {
                    scrollResistance = distanceFromTouch / kScrollResistanceFactorDefault;
                }
                
                let item = springBehaviour.items[0] as UICollectionViewLayoutAttributes
                
                var center = item.center;
                if delta < 0 {
                    center.x += max(delta, delta * scrollResistance);
                } else {
                    center.x += min(delta, delta * scrollResistance);
                }
                item.center = center;
                
                self.dynamicAnimator.updateItemUsingCurrentState(item)
                
            }
        }
        return false
    }
    
    /*
     override func prepareForCollectionViewUpdates(updateItems: AnyObject[]!) {
        super.prepareForCollectionViewUpdates(updateItems)
        
        println("prepareForCollectionViewUpdates")
        for updateItem in updateItems as UICollectionViewUpdateItem[] {
            
        }
    }
     */
}
