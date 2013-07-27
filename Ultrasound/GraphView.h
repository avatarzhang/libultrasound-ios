
#import <UIKit/UIKit.h>
#import "GraphViewUtils.h"


@class GraphView;
@protocol GraphViewDataSource
- (double) valueForXCoord:(double)x withIndex:(int) index graphView:(GraphView *)view;
@end

@interface GraphView : UIView

@property (nonatomic, weak) id <GraphViewDataSource> dataSource;
- (void) setupInitialTransforms;
- (void) generateBitmap;


// Methods to override
- (Transforms) initialTransforms;
- (CGPoint) tickMarkSpacing;

@end
