//
//  DOMElement_Additions.m
//  Glasses
//
//  Created by Pierre d'Herbemont on 8/22/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DOMElement_Additions.h"

@implementation DOMElement (DOMElementExtras)
- (NSPoint)absolutePosition
{
    DOMElement *parent = self.offsetParent;
    if (!parent)
        return NSMakePoint(self.offsetLeft, self.offsetTop);
	NSPoint parentPosition = [parent absolutePosition];
	return NSMakePoint(self.offsetLeft + parentPosition.x,  parentPosition.y + self.offsetTop);
}

- (NSRect)frameInView:(NSView *)view
{
    NSPoint origin = [self absolutePosition];
    return NSMakeRect(origin.x + 1, [view frame].size.height - origin.y - self.clientHeight, self.clientWidth, self.clientHeight);
}
@end
