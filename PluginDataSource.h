#include <Foundation/NSDictionary.h>
#include <UIKit/UIColor.h>
#include <UIKit/UIFont.h>
#include <UIKit/UITableView.h>
#include <UIKit/UIView.h>
#include <UIKit/UILabel.h>

@interface LITimeView : UIView
{
	BOOL is24Hour;
	NSDate* date;
	NSString* text;
}

@property (nonatomic) BOOL relative;
@property (nonatomic, retain) NSString* text;
@property (nonatomic, retain) NSDate* date;
-(BOOL) is24Hour;

@end

@interface LITableView : UITableView <UITableViewDataSource, UITableViewDelegate>
{
        NSMutableArray* sections;
        NSMutableDictionary* collapsed;
}

@property (nonatomic, retain) UIColor* headerColor;
@property (nonatomic, retain) UIFont* headerFont;

@property (nonatomic, retain) UIColor* summaryColor;
@property (nonatomic, retain) UIFont* summaryFont;

@property (nonatomic, retain) UIColor* detailColor;
@property (nonatomic, retain) UIFont* detailFont;

@property (nonatomic, retain) UIColor* shadowColor;
@property (nonatomic) CGSize shadowOffset;

-(BOOL) isCollapsed:(int) section;
-(BOOL) toggleSection:(int) section;

-(void) setProperties:(UILabel*) label summary:(BOOL) summary;
-(LITimeView*) timeViewWithFrame:(CGRect) frame;

@end

@interface LIPlugin : NSObject

- (id) lock;
- (void) updateView:(NSDictionary*) data;

@end

@protocol LIPluginDataSource <NSObject>

-(void) plugin:(LIPlugin*) plugin loadData:(NSDictionary*) prefs;

@end
