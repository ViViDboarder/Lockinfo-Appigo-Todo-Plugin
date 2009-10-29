#import "Foundation/Foundation.h"
#import <sqlite3.h>

#import <UIKit/UIKit.h>
#import <UIKit/UIApplication.h>
#include "PluginDataSource.h"
#include <stdarg.h>
#include <stdio.h>

/** Might not be needed for new API
@protocol PluginDelegate <NSObject>

// This data dictionary will be converted into JSON by the extension.  This method will get called
// any time an application is closed or the badge changes on the bundles in the LIManagedBundles setting and when the phone is woken up.  It'
- (NSDictionary*) data;

@optional
// Called before the first call to 'data' and any time the settings are updated in the Settings app.
- (void) setPreferences:(NSDictionary*) prefs;

@end
**/

@interface TodoView : UIView

@property (nonatomic, retain) LITimeView* time;
@property (nonatomic, retain) UILabel* theText;
@property (nonatomic, retain) UILabel* theFlags;
@property (nonatomic, retain) UILabel* theDate;

@end

@implementation TodoView

@synthesize time, theText, theFlags, theDate;

- (id)initWithFrame:(CGRect)frame timeView:(LITimeView*) timeView {
	self = [super initWithFrame:frame];
	self.backgroundColor = [UIColor clearColor];
	
	self.time = timeView;
	self.time.frame = CGRectMake(0, 0, 70, 18);
	self.time.backgroundColor = [UIColor clearColor];
	
    self.theText = [[UILabel alloc]init];
    self.theText.frame = CGRectMake(85, 0, 225, 18);
    self.theText.backgroundColor = [UIColor clearColor];

    self.theFlags = [[UILabel alloc]init];
    self.theFlags.frame = CGRectMake(85, 17, 225, 13);
    self.theFlags.backgroundColor = [UIColor clearColor];

    [self addSubview:self.time];
    [self addSubview:self.theText];
    [self addSubview:self.theFlags];

    return self;
}
/** Commented out as reference
 -(void) drawRect:(struct CGRect) rect {
	NSLog(@"LI:Todo: Rendering Items...");
	int width = (rect.size.width / 1);
	
	for (int i = 0; i < self.todos.count; i++) {// TODO: Change && i < 3 to read max value from .plist
		NSDictionary* todoItem = [self.todos objectAtIndex:i];
		NSString* theText = [todoItem objectForKey:@"text"];
		NSString* theDate = [todoItem objectForKey:@"due"];
		NSString* theFlags = [todoItem objectForKey:@"flags"];
		
		NSString* str = [NSString stringWithFormat: @"%@", theText];
		CGRect r = CGRectMake(rect.origin.x + 20, rect.origin.y + 4 + (i * 13) , width, 12);
		[[UIColor whiteColor] set];
		[str drawInRect:r withFont:[UIFont boldSystemFontOfSize:12] lineBreakMode:UILineBreakModeClip ];
	}
}
**/

@end


@interface TodoPlugin : NSObject <LIPluginDelegate, UITableViewDataSource> {
  //The date when the todos where read the last time
  NSDate *lastDataCheckout;
  //The date when the todo settings where read the last time (necessary for focus list)
  NSDate *lastSettingsCheckout;  
  NSDictionary *lastData;
  NSMutableDictionary *preferences;
  NSMutableDictionary *todoSettings;  
  int queryLimit;

  NSDictionary* sqlDict;
  NSString* preferencesPath;
  NSString* todoSettingsPath;
  NSString* todoSettingsFile;  
  NSString* databaseFile;
  NSString* applicationName;
  BOOL useLiteVersion;
     
  NSAutoreleasePool* pool;
}

@property (nonatomic, retain) NSArray* todoList;

- (NSDictionary*) data;
@end

@implementation TodoPlugin

@synthesize todoList;

- (id)init {
  self = [super init];

  lastData = nil;
  lastDataCheckout = nil;
  lastSettingsCheckout = nil;

  pool = [[NSAutoreleasePool alloc] init];
  
  //PluginSettings
  preferencesPath = @"/User/Library/Preferences/cx.ath.jakewalk.TodoPlugin.plist";
  preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:preferencesPath];

  //Uncomment for debugging
  //freopen("/tmp/logfile.log", "a", stderr);
 
  useLiteVersion = [[preferences objectForKey: @"Lite"] boolValue];
  
  //Decide if the plugin points to the full or the lite version
  if (useLiteVersion) {
  	  databaseFile = @"Documents/TodoLite_v5.sqlitedb";
	  applicationName = @"Todo Lite.app";
      todoSettingsFile = @"Library/Preferences/com.appigo.todolite.plist";    
  }
  else {
  	  databaseFile = @"Documents/Todo_v5.sqlitedb";
	  applicationName = @"Todo.app";
      todoSettingsFile = @"Library/Preferences/com.appigo.todo.plist";  	
  }

  NSFileManager* fm = [NSFileManager defaultManager];
  
  //Path to the Todo-Application (for example /User/Applications/AC624048-1944-4019-8581-407A502E19AC/)
  NSString* databasePath = [preferences objectForKey:@"databasePath"];
  
  NSLog(@"LI:Todo: databasePath: %@", databasePath);  
  
  if(databasePath == nil || [fm fileExistsAtPath:[[preferences objectForKey:@"databasePath"] stringByAppendingString:databaseFile]] == NO) {
	NSLog(@"LI:Todo: We do not have the database path, going to search for it.");

	NSString* appPath = @"/User/Applications/";
	NSArray* uuidDirs = [fm directoryContentsAtPath:appPath];
	NSEnumerator *e = [uuidDirs objectEnumerator];
	bool cont = true;
	NSString* uuid = nil;
	while(cont && (uuid = [e nextObject])) {
	  if([[fm directoryContentsAtPath:[appPath stringByAppendingString:uuid]] containsObject:applicationName]) {
		[preferences setObject:[NSString stringWithFormat:@"/User/Applications/%@/", uuid] forKey:@"databasePath"];
		[preferences writeToFile:preferencesPath atomically:YES];
		cont = false;
		NSLog(@"LI:Todo: Found the path: %@", [preferences objectForKey:@"databasePath"]);
	  }
	}	
  }

  NSLog(@"LI:Todo: path: %@", [preferences objectForKey:@"databasePath"]);

  [self CreateSQLQueries];

  queryLimit = [[preferences valueForKey:@"Limit"] intValue];

  NSLog(@"LI:Todo: Initialized!");

  return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.todoList.count;
}

- (UITableViewCell *)tableView:(LITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	//NSArray* todos = [lastData objectForKey:@"todos"];
	
	UITableViewCell *td = [tableView dequeueReusableCellWithIdentifier:@"TodoCell"];
	
	if (td == nil) {
		td = [[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"TodoCell"];
		td.backgroundColor = [UIColor clearColor];
		
		TodoView* tdv = [[[TodoView alloc] initWithFrame:CGRectMake(0, 0, 320, 35) timeView:[tableView timeViewWithFrame:CGRectZero]] autorelease];
		tdv.backgroundColor = [UIColor clearColor];
		tdv.tag = 57;
		[td.contentView addSubview:tdv];
	}
	
	TodoView* tdv = [td viewWithTag:57];
	[tableView setProperties:tdv.theText summary:YES];
	[tableView setProperties:tdv.theFlags summary:NO];
	
	if(self.todoList.count > indexPath.row) {
		NSDictionary* elem = [self.todoList objectAtIndex:indexPath.row];
		tdv.theText = [elem objectForKey:@"text"];
		//tdv.theDate = [elem objectForKey:@"due"];
		tdv.theFlags = [elem objectForKey:@"flags"];
		
		NSNumber* dateNum = [elem objectForKey:@"due"];
		tdv.time.date = [[[NSDate alloc] initWithTimeIntervalSince1970:dateNum.doubleValue / 1000] autorelease];
	}
	
	NSLog(@"LI:Todo: Just updated the Todo View");
	
	return td;

}

/**
- (void) plugin:(LIPlugin*) plugin loadData:(NSDictionary*) prefs{
	[self init];
	


}
**/

- (void) CreateSQLQueries {
	
  /* Focuslist Begin */
  /* Completed tasks shall never be shown on the lockscreen, other focus list settings are respected */
  
  /* Todo Settings (for Focus list) */
  todoSettingsPath = [[preferences objectForKey:@"databasePath"] stringByAppendingString:todoSettingsFile];
  todoSettings = [[NSMutableDictionary alloc] initWithContentsOfFile:todoSettingsPath];

  NSString *focusSql = @"select name,due_date,flags from tasks where deleted = 0 and completion_date < 0";

  /* Show tasks - No Due Date */
  if ([todoSettings objectForKey:@"FocusListShowUndatedTasks"]){
  	  //Show tasks without due date
  	  focusSql = [focusSql stringByAppendingString:@" and due_date <= 64092211200"];
	  NSLog(@"LI:Todo: FocusListShowUndatedTasks: true");
  }
  else {
  	  //Hide tasks without due date
  	  focusSql = [focusSql stringByAppendingString:@" and due_date < 64092211200"];    
  	  NSLog(@"LI:Todo: FocusListShowUndatedTasks: false");
  }

  /* List filter - don't show lists that are within the filter */
  NSEnumerator* e = [[todoSettings objectForKey:@"FocusFilteredLists"] objectEnumerator];
  id ListToFilter;

  while (ListToFilter = [e nextObject])
  {
    focusSql = [focusSql stringByAppendingString:@" and list <> %@"];    
 	focusSql = [NSString stringWithFormat:focusSql, ListToFilter];
  }

  /* Hide all tasks that are due after the specified distance */  
  //Today as Unixtime
  NSString *todayUnixtime = [NSString stringWithFormat:@"%d", (long)[[NSDate date] timeIntervalSince1970]];

  focusSql = [focusSql stringByAppendingString:@" and due_date < (%@ + %@)"];
  focusSql = [NSString stringWithFormat:focusSql, todayUnixtime, [todoSettings objectForKey:@"FocusListFilterDueTasksSetting"]];
 
  /* Hide all tasks that have not at least the specified priority */  
  focusSql = [focusSql stringByAppendingString:@" and priority <= %@"];
  focusSql = [NSString stringWithFormat:focusSql, [todoSettings objectForKey:@"FilterPriorityTasksSetting"]];  
 
  NSLog(@"LI:Todo: focusSql: %@", focusSql);

  /* Due todos from the inbox */
  NSString *inboxSql = @"select name,due_date,tasks.flags from tasks where completion_date < 0 and list = 0 and deleted = 0";

  /* Due todos from all lists */
  NSString *allSql = @"select name,due_date,tasks.flags from tasks where completion_date < 0 and deleted = 0";

  /* Due todos from a custom list (Home f.e.) */
  NSString *customSql = [NSString stringWithFormat:@"select tasks.name,due_date,tasks.flags FROM tasks INNER JOIN lists ON (tasks.list = lists.pk) WHERE lists.name = '%@' and completion_date < 0 and tasks.deleted = 0", [preferences objectForKey:@"customList"]];

  if(sqlDict != nil)
	[sqlDict release];

  sqlDict = [[NSDictionary alloc] initWithObjectsAndKeys:
								  inboxSql, @"inbox",
								  allSql, @"all",
								  focusSql, @"focus",							  
								  customSql, @"custom",							  								  
								  nil];
}

- (void)dealloc {
  if(lastData != nil)
	[lastData release];
  
  if(lastDataCheckout != nil)
	[lastDataCheckout release];

  if(lastSettingsCheckout != nil)
	[lastSettingsCheckout release];

  [sqlDict release];

  [preferences release];
  [todoSettings release];

  [pool release];

  [super dealloc];
}

- (NSDictionary*) readFromDatabase {
  //NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:1];
  NSMutableArray *todos = [NSMutableArray arrayWithCapacity:4];

  sqlite3 *database = NULL;

  if(sqlite3_open([[[preferences objectForKey:@"databasePath"] stringByAppendingString:databaseFile] UTF8String], &database) == SQLITE_OK) {

	/*
	  NSString *sql = [NSString stringWithFormat:@"%@ limit %i;",
	  todaySql,
	  [[preferences valueForKey:@"Limit"] intValue]];
	*/

	NSString *sql = [NSString stringWithFormat:@"%@ order by due_date ASC limit %i", 
							  [sqlDict objectForKey: [preferences objectForKey:@"List"]], 
							  queryLimit];

	// Setup the SQL Statement and compile it for faster access
	sqlite3_stmt *compiledStatement;
	if(sqlite3_prepare_v2(database, [sql UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK) {
	  NSLog(@"LI:Todo: Database checkout worked!");

	  // Loop through the results and add them to the feeds array
	  while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
		const char *cText = sqlite3_column_text(compiledStatement, 0);
		if(cText == NULL)
		  cText = "";

		const char *cDue  = sqlite3_column_text(compiledStatement, 1);
		if(cDue == NULL)
		  cDue = "";
		  
		const char *cFlags  = sqlite3_column_text(compiledStatement, 2);
		if(cFlags == NULL)
		  cFlags = "";		  
		
		NSString *aText = [NSString stringWithUTF8String:cText];
		NSString *aDue = [NSString stringWithUTF8String:cDue];
		NSString *aFlags = [NSString stringWithUTF8String:cFlags];

		NSDictionary *todoDict = [NSDictionary dictionaryWithObjectsAndKeys:
												 aText, @"text",
											   aDue, @"due",
											   aFlags, @"flags",											   
											   nil];
		
		[todos addObject:todoDict];
	  }
	  
	}
	// Release the compiled statement from memory
	sqlite3_finalize(compiledStatement);
  }

  sqlite3_close(database);

  [dict setObject:todos forKey:@"todos"];  
  [dict setObject:preferences forKey:@"preferences"];
  //[dict retain];
  
  //[pool drain];

  NSLog(@"LI:Todo: Successfully read from database.");
  
  //@synchronized (plugin.lock) {
  	self.todoList = todos;
  	//[plugin updateView:dict];
  //}

  return dict;
}

- (NSDictionary*) data {
  NSAutoreleasePool *datapool = [[NSAutoreleasePool alloc] init];

  /* Get the todo database timestamp */
  NSDictionary *dataFileAttributes = [[NSFileManager defaultManager] 
								   fileAttributesAtPath:[[preferences objectForKey:@"databasePath"] stringByAppendingString:databaseFile]
								   traverseLink:YES];

  NSDate* lastDataModified = [dataFileAttributes objectForKey:NSFileModificationDate];

  NSLog(@"LI:Todo: lastDataModified: %@", lastDataModified);  
  NSLog(@"LI:Todo: lastDataCheckout: %@", lastDataCheckout);  

  /* Get the todo settings timestamp */  
  NSDictionary *settingsFileAttributes = [[NSFileManager defaultManager] 
								   fileAttributesAtPath:[[preferences objectForKey:@"databasePath"] stringByAppendingString:todoSettingsFile]
								   traverseLink:YES];

  NSDate* lastSettingsModified = [settingsFileAttributes objectForKey:NSFileModificationDate];

  NSLog(@"LI:Todo: lastSettingsModified: %@", lastSettingsModified);  
  NSLog(@"LI:Todo: lastSettingsCheckout: %@", lastSettingsCheckout);    

  if(lastDataCheckout == nil || lastSettingsCheckout == nil || lastData == nil ||
	 [lastDataModified compare:lastDataCheckout] == NSOrderedDescending ||
	 [lastSettingsModified compare:lastSettingsCheckout] == NSOrderedDescending) {
	NSLog(@"LI:Todo: We don't have the last time, data or todo-settings -> updating");
	
	if([lastSettingsModified compare:lastSettingsCheckout] == NSOrderedDescending){
		[self CreateSQLQueries];
	}

	NSDictionary* dict = [self readFromDatabase];	

	if(lastData != nil)
	  [lastData release];
	lastData = [dict retain];

	if(lastDataCheckout != nil)
	  [lastDataCheckout release];
	lastDataCheckout = [lastDataModified retain];

	if(lastSettingsCheckout != nil)
	  [lastSettingsCheckout release];
	lastSettingsCheckout = [lastSettingsModified retain];

	NSLog(@"LI:Todo: Succesfully got new data");
	

	
  } else {
	NSLog(@"LI:Todo: No update necessary");
  }
  
  [datapool drain];
  
  return lastData;
}

- (void) setPreferences:(NSDictionary*) prefs {
  [preferences release];
  preferences = [prefs retain];

  queryLimit = [[preferences valueForKey:@"Limit"] intValue];

  //Force an update of the data
  if(lastData != nil) {
	[lastData release];
	lastData = nil;
  }

  NSLog(@"LI:Todo: PreferencesChanged");
}

@end

int main() {
  /*
  //  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  TodoPlugin* p = [[TodoPlugin alloc] init];
  GSLog(@"%@", [p data]);

  //  [pool release];
  */
}
