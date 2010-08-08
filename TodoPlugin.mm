#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <sqlite3.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplication.h>
#include "../LockInfo/Plugin.h"

extern "C" CFStringRef UIDateFormatStringForFormatType(CFStringRef type);

#define localize(bundle, str) \
	[bundle localizedStringForKey:str value:str table:nil]
#define localizeGlobal(str) \
[self.plugin.globalBundle localizedStringForKey:str value:str table:nil]

static SBApplication* getApp()
{
	Class cls = objc_getClass("SBApplicationController");
	SBApplicationController* ctr = [cls sharedInstance];

	SBApplication* app = [ctr applicationWithDisplayIdentifier:@"com.appigo.todo"];

	if (app == nil)
		app = [ctr applicationWithDisplayIdentifier:@"com.appigo.todolite"];

	return app;
}

@interface DotView : UIView

@property (nonatomic, retain) UIColor* color;

@end

@implementation DotView

@synthesize color;

-(void) drawRect:(CGRect) rect
{
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[self.color set];
	CGContextFillEllipseInRect(ctx, rect);

	NSBundle* b = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/CalendarUI.framework"];
	NSString* path = [b pathForResource:@"dotshine" ofType:@"png"];
	UIImage* image = [UIImage imageWithContentsOfFile:path];
	[image drawInRect:rect];
}
@end

@interface TodoView : UIView

@property (nonatomic, retain) DotView* dot;
@property (nonatomic, retain) LILabel* name;
@property (nonatomic, retain) LILabel* due;
@property (nonatomic, retain) UIImageView* priority;

@end

@implementation TodoView

@synthesize dot, due, name, priority;

@end

static TodoView* createView(CGRect frame, LITableView* table)
{
	TodoView* v = [[[TodoView alloc] initWithFrame:frame] autorelease];
	v.backgroundColor = [UIColor clearColor];

	v.dot = [[[DotView alloc] initWithFrame:CGRectMake(4, 4, 9, 9)] autorelease];
	v.dot.backgroundColor = [UIColor clearColor];
	
	v.name = [table labelWithFrame:CGRectZero];
	v.name.frame = CGRectMake(22, 0, 275, 16);
	v.name.backgroundColor = [UIColor clearColor];

	v.due = [table labelWithFrame:CGRectZero];
	v.due.frame = CGRectMake(22, 16, 275, 14);
	v.due.backgroundColor = [UIColor clearColor];

	v.priority = [[[UIImageView alloc] initWithFrame:CGRectMake(305, 3, 10, 10)] autorelease];
	v.priority.backgroundColor = [UIColor clearColor];

	[v addSubview:v.dot];	
	[v addSubview:v.name];
	[v addSubview:v.priority];
	[v addSubview:v.due];

	return v;
}

@interface TodoPreview : UIView
{
	int indexRow;
	CGRect* rect;
}

@property (retain) NSArray* todoListP;
@property (nonatomic, retain) LIPlugin* plugin;
@property (retain) NSString* dbPath;

- (id) initWithFrame: (CGRect*) r withList: (NSArray*) l atIndex: (NSIndexPath*) i withPlugin: (LIPlugin*) p;
- (void) buildPreview;
- (void) markComplete;
- (void) setRect: (CGRect*) r;
- (CGRect*) getRect;
- (void) setIndex: (int) i;
- (int) getIndex;

@end

@implementation TodoPreview

@synthesize plugin, todoListP, dbPath;//, rect;

- (id) initWithFrame: (CGRect*) r withList: (NSArray*) l atIndex: (NSIndexPath*) i withPlugin: (LIPlugin*) p
{
	self = [super initWithFrame: *r];
	
	if (self)
    {
		self.todoListP = l;
		[self setIndex: i.row];
		[self setRect: r];
        self.plugin = p;
		[self buildPreview];
	}
    
    return self;
}

- (void) setRect: (CGRect*) r
{
	rect = r;
}

- (CGRect*) getRect
{
    return rect;
}

- (void) setIndex: (int) i
{
	indexRow = i;
}

- (int) getIndex
{
	return indexRow;
}

- (void) buildPreview
{
	super.backgroundColor = [UIColor whiteColor];
	
	NSDictionary* elem = [self.todoListP objectAtIndex: [self getIndex]];
	
	UIToolbar* nav = [[[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
	nav.barStyle = UIBarStyleBlackOpaque;
	nav.items = [NSArray arrayWithObjects:[[[UIBarButtonItem alloc] initWithTitle:localizeGlobal(@"Done") style:UIBarButtonItemStyleBordered target:self.plugin action:@selector(dismissPreview)] autorelease], nil];
	[self addSubview:nav];
	
	// If the item is NOT a Project (1) or Checklist (7) then show the bar on the bottom to mark complete
	int theType = [[elem objectForKey:@"type"] intValue];
	if (theType != 1 && theType != 7) {
		UIToolbar* actionBar = [[[UIToolbar alloc] initWithFrame:CGRectMake(0, rect->size.height - 44, 320, 44)] autorelease];
		actionBar.barStyle = UIBarStyleBlackOpaque;
		actionBar.items = [NSArray arrayWithObjects:[[[UIBarButtonItem alloc] initWithTitle:@"Mark Complete" style:UIBarButtonItemStyleBordered target:self action:@selector(markComplete)] autorelease], nil];
		[self addSubview:actionBar];
		
		// Adjust Rect for bottom bar
		rect->size.height -= actionBar.frame.size.height;
	}
	
    // Adjust Rect for top bar
	rect->origin.y = nav.frame.size.height;
	rect->size.height -= rect->origin.y;
    
//	UIView *theBackground = [[[UIView alloc] initWithFrame:*rect] autorelase];
//    theBackground.backgroundColor = [UIColor whiteColor];
    
	UILabel *theText = [[[UILabel alloc] initWithFrame:*rect] autorelease];
	theText.backgroundColor = [UIColor whiteColor];
	theText.lineBreakMode = UILineBreakModeWordWrap;
	theText.numberOfLines = 0;
	
	NSString *theDetails = [elem objectForKey:@"name"];
	//theDetails = [theDetails stringByT];
	//if (theDetails = @"") {
	//	theDetails = @"No details...";
	//}
	
	
	// Append Note here...
	theDetails = [NSString stringWithFormat:@"%@: \n%@", theDetails, [elem objectForKey:@"note"]];
	theText.text = theDetails;
	
	[theText sizeToFit];
	theText.frame = CGRectMake(7,rect->origin.y,rect->size.width - 7, theText.frame.size.height);
	
    //[theBackground addSubview: theText];
    //[self addSubview: theBackground];
	[self addSubview:theText];
	
	//[self resizePreview:thePreview];
	//[self.plugin updateView];
	
}

- (void) markComplete
{
    NSDictionary* elem = [self.todoListP objectAtIndex: [self getIndex]];
    
    int pk = [[elem objectForKey:@"primaryKey"] intValue];
	//NSLog(@"LI:Todo: Mark Item Completed Index: %d PK: %d", [self getIndex], pk);
    
    NSString *allSQL = [NSString stringWithFormat: @"UPDATE tasks SET completion_date = strftime('%%s','now') WHERE pk = %d", pk]; 
    NSLog(@"LI:Todo: Execute SQL: %@", allSQL);
    
    const char* sql;
    sql = [allSQL cStringUsingEncoding:[NSString defaultCStringEncoding]];
    if (self.dbPath == nil)
	{
		SBApplication* app = getApp();
		BOOL lite = [app.displayIdentifier isEqualToString:@"com.appigo.todolite"];
		NSString* appPath = [app.path stringByDeletingLastPathComponent];
		NSString* prefsPath = [appPath stringByAppendingFormat:@"/Library/Preferences/%@.plist", app.displayIdentifier];
		NSDictionary* metadata;
		if (lite) {
			metadata = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingFormat:@"/Todo.app/Info.plist"]];
		}
		else {
			metadata = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingFormat:@"/Todo.app/Info.plist"]];
		}
		NSString* v = [metadata valueForKey:@"CFBundleVersion"];
		
		int version = 1;
		if (version == 2168602)
		{
			self.dbPath = [[appPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:(lite ? @"TodoLite_v5.sqlitedb" : @"Todo_v5.sqlitedb")];
			
		}
		else
		{
			self.dbPath = [[appPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:(lite ? @"TodoLite_v6.sqlitedb" : @"Todo_v6.sqlitedb")];
		}
		
	}
    
    sqlite3 *database = NULL;
    @try
    {		
        if (sqlite3_open([self.dbPath UTF8String], &database) != SQLITE_OK) 
        {
            NSLog(@"LI:Todo: Failed to open database.");
            return;
        }
        
        @try
        {
            sqlite3_exec(database, sql, nil, nil, nil);
        }
        @finally
        {			
            
        }
    }
    @finally
    {
        if (database != NULL)
            sqlite3_close(database);
    }
    
    [self.plugin dismissPreview];
	
	[self.plugin.tableViewDelegate updateTasks];
}

@end



@interface TodoPlugin : NSObject <LIPluginController, LITableViewDelegate, UITableViewDataSource> 
{
	NSTimeInterval lastUpdate;
}

@property (nonatomic, retain) LIPlugin* plugin;
@property (retain) NSDictionary* todoPrefs;
@property (retain) NSArray* todoList;

@property (retain) NSString* sql;
@property (retain) NSString* prefsPath;
@property (retain) NSString* dbPath;

@end

@implementation TodoPlugin

@synthesize todoList, todoPrefs, sql, plugin, prefsPath, dbPath;

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return self.todoList.count;
}

- (UITableViewCell *)tableView:(LITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TodoCell"];
	
	BOOL showDate = true;
	if (NSNumber* p = [self.plugin.preferences valueForKey:@"ShowDate"])
		showDate = p.boolValue;
	
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"TodoCell"] autorelease];
		//cell.backgroundColor = [UIColor clearColor];
		
		TodoView* v;
		if (showDate) {
			v = createView(CGRectMake(0, 0, 320, 35), tableView);
		}
		else {
			v = createView(CGRectMake(0, 0, 320, 19), tableView);
		}

		v.tag = 57;
		[cell.contentView addSubview:v];
	}
	
	TodoView* v = [cell.contentView viewWithTag:57];
	v.name.style = tableView.theme.summaryStyle;
	
	NSDictionary* elem = [self.todoList objectAtIndex:indexPath.row];
	v.name.text = [elem objectForKey:@"name"];
	
	BOOL ind = true;
	if (NSNumber* b = [self.todoPrefs objectForKey:@"ShowListColors"])
		ind = b.boolValue;

	if (ind)
	{
		UIColor* color = [UIColor colorWithRed:[[elem objectForKey:@"color_r"] doubleValue]
					green:[[elem objectForKey:@"color_g"] doubleValue]
					blue:[[elem objectForKey:@"color_b"] doubleValue]
					alpha:1];
		v.dot.color = color;
		v.dot.hidden = false;
		[v.dot setNeedsDisplay];
	}
	else
	{
		v.dot.hidden = true;
	}
		
	if (showDate) {		
		NSNumber* dateNum = [elem objectForKey:@"due"];
		if (dateNum.doubleValue == 64092211200.0)
		{
			NSBundle* bundle = [NSBundle bundleForClass:[self class]];
			v.due.style = tableView.theme.detailStyle;
			v.due.text = localize(bundle, @"No Due Date");
		}
		else
		{
			int flags = [[elem objectForKey:@"flags"] intValue];
			
			//NSLog(@"LI:Todo: Flags %d", flags);
			
			NSDate* date = [[[NSDate alloc] initWithTimeIntervalSince1970:dateNum.doubleValue] autorelease];
			NSDate *today = [NSDate date];
			
			NSDateFormatter* df = [[[NSDateFormatter alloc] init] autorelease];
			if (flags % 2 == 1) {
				df.dateFormat = (NSString*)UIDateFormatStringForFormatType(CFSTR("UIAbbreviatedWeekdayMonthDayTimeFormat"));
			}
			else {
				df.dateFormat = (NSString*)UIDateFormatStringForFormatType(CFSTR("UIAbbreviatedWeekdayMonthDayFormat"));
			}
			
			int theColor = 0;
			if (NSNumber* n = [self.plugin.preferences valueForKey:@"OverdueColor"])
				theColor = n.intValue;
			
			//NSLog(@"LI:Todo: Color int = %d", theColor);
			
			if (theColor != 0 && [date compare:today] == NSOrderedAscending) {
				v.due.style = [[tableView.theme.detailStyle copy] autorelease];
				switch (theColor) {
					case 1:
						//NSLog(@"LI:Todo: TextColor = Red");
						v.due.style.textColor = [UIColor redColor];
						break;
					case 2:
						//NSLog(@"LI:Todo: TextColor = Blue");
						v.due.style.textColor = [UIColor blueColor];
						break;
					case 3:
						//NSLog(@"LI:Todo: TextColor = Green");
						v.due.style.textColor = [UIColor greenColor];
						break;
					case 4:
						//NSLog(@"LI:Todo: TextColor = Yellow");
						v.due.style.textColor = [UIColor yellowColor];
						break;
					case 5:
						//NSLog(@"LI:Todo: TextColor = Orange");
						v.due.style.textColor = [UIColor orangeColor];
						break;
					default:
						break;
				}
				
			}
			else {
				v.due.style = tableView.theme.detailStyle;
			}
			if (isToday(date)) {
				v.due.text = @"Today";
			} else if (isTomorrow(date)){
				v.due.text = @"Tomorrow";
			} else {
				v.due.text = [df stringFromDate:date];
			}
		}
	}
	else {
		
		v.due.frame.size.height = 0;
	}

	BOOL prior = true;
	if (NSNumber* p = [self.plugin.preferences valueForKey:@"ShowPriority"])
		prior = p.boolValue;
	
	if (prior)
	{
		int priority = [[elem objectForKey:@"priority"] intValue];
		NSString* imagePath = [NSString stringWithFormat:@"/Library/LockInfo/Plugins/com.vividboarder.lockinfo.TodoPlugin.bundle/todo_%d.png", priority];
		
		v.priority.image = [UIImage imageWithContentsOfFile:imagePath];
	}
	else
	{
		v.priority.hidden = true;
	}
	
	// Resize Sections
	v.name.lineBreakMode = UILineBreakModeWordWrap;
	[v.name sizeToFit];
	v.name.frame = CGRectMake(22, 0, 275, tableView.theme.summaryStyle.font.pointSize + 2);
	
	[v.due sizeToFit];
	v.due.frame = CGRectMake(22, v.name.frame.size.height + 1 , 275, tableView.theme.detailStyle.font.pointSize + 2);
	
	[v sizeToFit];
	[cell sizeToFit];
	v.frame = CGRectMake(0, 0, 320, v.name.frame.size.height + v.due.frame.size.height);
	cell.frame = CGRectMake(0, 0, 320, v.name.frame.size.height + v.due.frame.size.height);
	
	return cell;
}

- (CGFloat)tableView:(LITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	BOOL showDate = true;
	if (NSNumber* p = [self.plugin.preferences valueForKey:@"ShowDate"])
		showDate = p.boolValue;
	
	CGFloat result;
	result = 0;
	
	result = result + tableView.theme.summaryStyle.font.pointSize + 3;
	
	if (showDate) {
		
		result = result + tableView.theme.detailStyle.font.pointSize + 2;
		
	}

	return result;
}

- (id) initWithPlugin:(LIPlugin*) plugin
{
	self = [super init];
	self.plugin = plugin;
	
	plugin.tableViewDataSource = self;
	plugin.tableViewDelegate = self;

	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(update:) name:LITimerNotification object:nil];
	[center addObserver:self selector:@selector(update:) name:LIViewReadyNotification object:nil];

	return self;
}

- (void) updateTasks
{
	if (self.dbPath == nil)
	{
		SBApplication* app = getApp();
		BOOL lite = [app.displayIdentifier isEqualToString:@"com.appigo.todolite"];
		NSString* appPath = [app.path stringByDeletingLastPathComponent];
		self.prefsPath = [appPath stringByAppendingFormat:@"/Library/Preferences/%@.plist", app.displayIdentifier];
		NSDictionary* metadata = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingFormat:@"/iTunesMetadata.plist"]];
		NSNumber* v = [metadata valueForKey:@"softwareVersionExternalIdentifier"];
		int version = v.intValue;
		NSLog(@"LI:Todo: Version %d", version);
		if (version == 2168602)
		{
			self.dbPath = [[appPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:(lite ? @"TodoLite_v5.sqlitedb" : @"Todo_v5.sqlitedb")];

		}
		else
		{
			self.dbPath = [[appPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:(lite ? @"TodoLite_v6.sqlitedb" : @"Todo_v6.sqlitedb")];
		}

	}
	self.todoPrefs = [NSDictionary dictionaryWithContentsOfFile:self.prefsPath];
	
	NSLog(@"LI:Todo: DB Path: %@", self.dbPath);
	//	NSLog(@"LI:Todo: Prefs: %@: %@", self.prefsPath, self.todoPrefs);
	
	NSString *allSql = @"select tasks.name, tasks.due_date, tasks.priority, lists.color, tasks.note, tasks.pk, tasks.flags, tasks.type from tasks left outer join lists on lists.pk = tasks.list where tasks.completion_date < 0 and tasks.deleted = 0";
		
	BOOL hideUnfiled = false;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"HideUnfiled"])
			hideUnfiled = n.boolValue;

	if (hideUnfiled)
		allSql = [allSql stringByAppendingString:@" and tasks.list <> 0"];
	
	BOOL dayLimit = true;
	int maxDays = 7;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"dayLimit"])
		dayLimit = n.boolValue;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"maxDays"])
		maxDays = n.intValue;
	if (dayLimit)
		if (maxDays == 0) {
			
			allSql = [NSString stringWithFormat:@"%@ and (date(tasks.due_date, 'unixepoch') <= date('now', '+%i day') or tasks.due_date = 64092211200)", allSql, maxDays];
		}
		else {
			allSql = [NSString stringWithFormat:@"%@ and (datetime(tasks.due_date, 'unixepoch') < datetime('now', '+%i day') or tasks.due_date = 64092211200)", allSql, maxDays];
		}
	
	BOOL showStarredOnly = false;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"showStarredOnly"])
		showStarredOnly = n.boolValue;
	if (showStarredOnly)
		allSql = [allSql stringByAppendingString:@" and tasks.starred = 1"];
					
	BOOL showLockscreenOnly = false;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"showLockscreenOnly"])
		showLockscreenOnly = n.boolValue;
	if (showLockscreenOnly)
		allSql = [allSql stringByAppendingString:@" and tasks.tags like '%Lockscreen%'"];
	
	BOOL hideSubItems = true;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"hideSubItems"])
		hideSubItems = n.boolValue;
	if (hideSubItems)
		allSql = [allSql stringByAppendingString:@" and tasks.parent = 0"];
	
	BOOL hideProjects = true;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"hideProjects"])
		hideProjects = n.boolValue;
	if (hideProjects)
		allSql = [allSql stringByAppendingString:@" and (tasks.type != 1 AND tasks.type != 7)"];
	
		
	BOOL hideNoDate = false;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"HideNoDate"])
		hideNoDate = n.boolValue;

	if (hideNoDate)
		allSql = [allSql stringByAppendingString:@" and tasks.due_date <> 64092211200"];

	int queryLimit = 5;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"MaxTasks"])
		queryLimit = n.intValue;

	NSString* sql = [NSString stringWithFormat:@"%@ order by tasks.due_date, tasks.priority ASC limit %i", allSql, queryLimit];
	
	BOOL overrideSQL = false;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"OverrideSQL"]) {
		overrideSQL = n.boolValue;
	}
	
	if (overrideSQL) {
		try {
			NSString* pathToSQL = @"/Library/LockInfo/Plugins/com.vividboarder.lockinfo.TodoPlugin.bundle/sql.txt";
			NSString* newSQL = [NSString stringWithContentsOfFile:pathToSQL];
			sql = newSQL;
		}
		catch (NSException* e){
			NSLog(@"LI:Todo: Failed to extract text from sql.txt Exception: %@", e);
		}
		
	}
	
	NSLog(@"LI:Todo: Executing SQL: %@", sql);
			
	/* Get the todo database timestamp */
	//NSFileManager* fm = [NSFileManager defaultManager];
	NSDictionary *dataFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:self.dbPath traverseLink:YES];
	NSDate* lastDataModified = [dataFileAttributes objectForKey:NSFileModificationDate];
	
	if(![sql isEqualToString:self.sql] || lastUpdate < lastDataModified.timeIntervalSinceReferenceDate)
	{
		NSLog(@"LI:Todo: Loading Todo Tasks...");
		self.sql = sql;

		// Update data and read from database
		NSMutableArray *todos = [NSMutableArray arrayWithCapacity:4];
		
		sqlite3 *database = NULL;
		@try
		{		
			if (sqlite3_open([self.dbPath UTF8String], &database) != SQLITE_OK) 
			{
				NSLog(@"LI:Todo: Failed to open database.");
				return;
			}

			// Setup the SQL Statement and compile it for faster access
			sqlite3_stmt *compiledStatement = NULL;

			@try
			{
				if (sqlite3_prepare_v2(database, [sql UTF8String], -1, &compiledStatement, NULL) != SQLITE_OK) 
				{
					NSLog(@"LI:Todo: Failed to prepare statement: %s", sqlite3_errmsg(database));
					return;
				}
		
						
				// Loop through the results and add them to the feeds array
				while(sqlite3_step(compiledStatement) == SQLITE_ROW) 
				{
					const char *cText = (const char*)sqlite3_column_text(compiledStatement, 0);
					double cDue  = sqlite3_column_double(compiledStatement, 1);
					int priority  = sqlite3_column_int(compiledStatement, 2);
					const char* cColor  = (const char*)sqlite3_column_text(compiledStatement, 3);
					const char *cNote = (const char*)sqlite3_column_text(compiledStatement, 4);
					int primaryKey  = sqlite3_column_int(compiledStatement, 5);
					int flags  = sqlite3_column_int(compiledStatement, 6);
					int theType = sqlite3_column_int(compiledStatement, 7);
							
					NSString *aText = [NSString stringWithUTF8String:(cText == NULL ? "" : cText)];
					NSString *color = (cColor == NULL ? [self.todoPrefs objectForKey:@"UnfiledTaskListColor"] : [NSString stringWithUTF8String:cColor]);
					NSArray* colorComps = [color componentsSeparatedByString:@":"];
					NSString *aNote = [NSString stringWithUTF8String:(cNote == NULL ? "No Notes." : cNote)];
							
					NSDictionary *todoDict = [NSDictionary dictionaryWithObjectsAndKeys:
						aText, @"name",
						[NSNumber numberWithDouble:cDue], @"due",
						[NSNumber numberWithInt:priority], @"priority", 
						[NSNumber numberWithDouble:(colorComps.count == 4 ? [[colorComps objectAtIndex:0] doubleValue] : 0)], @"color_r",
						[NSNumber numberWithDouble:(colorComps.count == 4 ? [[colorComps objectAtIndex:1] doubleValue] : 0)], @"color_g",
						[NSNumber numberWithDouble:(colorComps.count == 4 ? [[colorComps objectAtIndex:2] doubleValue] : 0)], @"color_b",
						aNote, @"note",
						[NSNumber numberWithInt:primaryKey], @"primaryKey", 
						[NSNumber numberWithInt:flags], @"flags", 
						[NSNumber numberWithInt:theType], @"type",
						nil];
				
					[todos addObject:todoDict];
				}
			}
			@finally
			{			
				if (compiledStatement != NULL)
					sqlite3_finalize(compiledStatement);
			}
		}
		@finally
		{
			if (database != NULL)
				sqlite3_close(database);
		}
	
		[self performSelectorOnMainThread:@selector(setTodoList:) withObject:todos waitUntilDone:YES];	

        NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:1];
		[dict setObject:todos forKey:@"todos"];  
		[[NSNotificationCenter defaultCenter] postNotificationName:LIUpdateViewNotification object:self.plugin userInfo:dict];
		
		lastUpdate = lastDataModified.timeIntervalSinceReferenceDate;
	}
}

- (void) update:(NSNotification*) notif
{
	if (!self.plugin.enabled)
		return;

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[self updateTasks];
	[pool release];
}

-(void) tableView:(LITableView*) table reloadDataInSection:(NSInteger) section
{
	[self updateTasks];
}

-(UIView*) tableView:(LITableView*) tableView previewWithFrame:(CGRect) rect forRowAtIndexPath:(NSIndexPath*) indexPath
{
	BOOL allowPreviews= true;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"allowPreviews"])
		allowPreviews = n.boolValue;
	
	if (indexPath.section >= self.todoList.count || !allowPreviews) {
		return nil;
	}
	
	TodoPreview *thePreview = [[[TodoPreview alloc] initWithFrame: &rect withList: self.todoList atIndex: indexPath withPlugin: self.plugin] autorelease];
	thePreview.backgroundColor = [UIColor whiteColor];
	
	return thePreview;
}

@end
