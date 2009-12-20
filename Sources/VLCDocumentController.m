/*****************************************************************************
 * Copyright (C) 2009 the VideoLAN team
 *
 * Authors: Felix Paul Kühne <fkuehne at videolan dot org>
 *          Pierre d'Herbemont
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCDocumentController.h"
#import "VLCMediaDocument.h"
#import "VLCSplashScreenWindowController.h"

@interface NSResponder (StyleMenuItemHandling)
- (void)setStyleFromMenuItem:(id)sender;
- (void)setSubtitleTrackFromMenuItem:(NSMenuItem *)sender;
- (void)setAudioTrackFromMenuItem:(NSMenuItem *)sender;
- (void)setChapterFromMenuItem:(NSMenuItem *)sender;
- (void)setTitleFromMenuItem:(NSMenuItem *)sender;
@end

@implementation VLCDocumentController

- (void)awakeFromNib
{
    [NSApp setDelegate:self];
}

- (BOOL) becomeFirstResponder
{
    return YES;
}

- (NSString *)typeForContentsOfURL:(NSURL *)inAbsoluteURL error:(NSError **)outError
{
    if ([[inAbsoluteURL scheme] isEqualToString:@"http"] || [[inAbsoluteURL scheme] isEqualToString:@"mms"]
     || [[inAbsoluteURL scheme] isEqualToString:@"ftp"] || [[inAbsoluteURL scheme] isEqualToString:@"rtsp"]
     || [[inAbsoluteURL scheme] isEqualToString:@"rtmp"] || [[inAbsoluteURL scheme] isEqualToString:@"udp"]
     || [[inAbsoluteURL scheme] isEqualToString:@"file"] || [[inAbsoluteURL scheme] isEqualToString:@"rtp"])
    {
        return @"VLCMediaDocument";
    }

    return nil;
}

- (Class)documentClassForType:(NSString *)typeName
{
    return [VLCMediaDocument class];
}

#pragma mark -
#pragma mark Main Menu Cleanup and Recreation

static NSMenuItem *createStyleMenuItemWithPlugInName(NSString *name)
{
    return [[NSMenuItem alloc] initWithTitle:name action:@selector(setStyleFromMenuItem:) keyEquivalent:@""];
}

- (void)rebuildStyleMenu
{
    NSString *pluginsPath = [[NSBundle mainBundle] builtInPlugInsPath];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *plugins = [manager contentsOfDirectoryAtPath:pluginsPath error:nil];
    NSAssert(_styleMenu, @"There is no style menu connected");
    
    // First add the special 'Default' menu and a separator
    NSMenuItem *menuItem = createStyleMenuItemWithPlugInName(@"Default");
    [[_styleMenu submenu] addItem:menuItem];
    [menuItem release];
    [[_styleMenu submenu] addItem:[NSMenuItem separatorItem]];
    
    for (NSString *pluginPath in plugins) {
        if (![pluginPath hasSuffix:@".lunettesstyle"])
            continue;
        // Don't add the Default plugin twice
        if ([pluginPath isEqualToString:@"Default.lunettesstyle"])
            continue;
        NSString *pluginName = [[pluginPath lastPathComponent] stringByDeletingPathExtension];
        NSMenuItem *menuItem = createStyleMenuItemWithPlugInName(pluginName);
        [[_styleMenu submenu] addItem:menuItem];
        [menuItem release];
        
    }
}

#define setupTrackMenu(parentMenuItem, selMeth, itemCount, label, currentItem)  \
menuItem = [[NSMenuItem alloc] initWithTitle:@"Disable" action:@selector(selMeth) keyEquivalent:@""]; \
[menuItem setTag:0]; \
[menuItem setAlternate:YES]; \
[[parentMenuItem submenu] addItem:menuItem]; \
[menuItem release]; \
[[parentMenuItem submenu] addItem:[NSMenuItem separatorItem]]; \
while (x < [thePlayer itemCount]) \
{ \
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:label,x] action:@selector(selMeth) keyEquivalent:@""]; \
    [menuItem setTag:x]; \
    [[parentMenuItem submenu] addItem:menuItem]; \
    [menuItem release]; \
    x++; \
} \
if ([[parentMenuItem submenu] numberOfItems] > 2) \
{ \
    [[[parentMenuItem submenu] itemWithTag:[thePlayer currentItem]] setState:NSOnState]; \
    [parentMenuItem setEnabled:YES]; \
} \
x = 1;

- (void)cleanAndRecreateMainMenu
{
    [_sharedOnLANMenuItem setState:[[self currentDocument] sharedOnLAN] ? NSOnState : NSOffState];
    [_repeatsCurrentItemMenuItem setState:[[self currentDocument] repeatsCurrentItem] ? NSOnState : NSOffState];
    if ([[[[self currentDocument] mediaListPlayer] mediaList] count] > 2)
        [_repeatsAllItemsMenuItem setState:[[self currentDocument] repeatsAllItems] ? NSOnState : NSOffState];

    [_subtitleTrackSelectorMenuItem setEnabled:NO];
    [_audioTrackSelectorMenuItem setEnabled:NO];
    [_titleSelectorMenuItem setEnabled:NO];
    [_chapterSelectorMenuItem setEnabled:NO];

    VLCMediaPlayer * thePlayer = [[[self currentDocument] mediaListPlayer] mediaPlayer];
    if ([thePlayer state] == VLCMediaPlayerStatePlaying || [thePlayer state] == VLCMediaPlayerStatePaused)
    {
        NSInteger x = 1;
        NSMenuItem *menuItem;

        // Subtitle menu
        // this is a special case to allow opening of external subtitle files
        [[_subtitleTrackSelectorMenuItem submenu] removeAllItems];
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Open Subtitle File..." action:@selector(setSubtitleTrackFromMenuItem:) keyEquivalent:@""];
        [menuItem setTag:-100];
        [[_subtitleTrackSelectorMenuItem submenu] addItem:menuItem];
        [menuItem release];
        [[_subtitleTrackSelectorMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        setupTrackMenu(_subtitleTrackSelectorMenuItem, setSubtitleTrackFromMenuItem:, countOfVideoSubTitles, @"Track %i", currentVideoSubTitles);
        if ([[_subtitleTrackSelectorMenuItem submenu] numberOfItems] == 4)
        {
            [[_subtitleTrackSelectorMenuItem submenu] removeItemAtIndex: 3]; // separator
            [[_subtitleTrackSelectorMenuItem submenu] removeItemAtIndex: 2]; // "Disable"
            [[_subtitleTrackSelectorMenuItem submenu] removeItemAtIndex: 1]; // separator
        }

        // Audiotrack menu
        [[_audioTrackSelectorMenuItem submenu] removeAllItems];
        setupTrackMenu(_audioTrackSelectorMenuItem, setAudioTrackFromMenuItem:, countOfAudioTracks, @"Track %i", currentAudioTrack);

        // Chapter Selector menu
        [[_chapterSelectorMenuItem submenu] removeAllItems];
        setupTrackMenu(_chapterSelectorMenuItem, setChapterFromMenuItem:, countOfChapters, @"Chapter %i", currentChapter);

        // Title selector menu
        [[_titleSelectorMenuItem submenu] removeAllItems];
        setupTrackMenu(_titleSelectorMenuItem, setTitleFromMenuItem:, countOfTitles, @"Title %i", currentTitle);
    }
}

- (NSPredicate *)predicateThatFiltersEmptyDiscoverer
{
    return [NSPredicate predicateWithFormat:@"discoveredMedia.media.@count != 0"];
}

- (void)bakeDocument:(VLCMediaDocument *)mediaDocument
{
    [self addDocument:mediaDocument];
    [mediaDocument makeWindowControllers];
    [mediaDocument showWindows];
}

- (void)makeDocumentWithMediaList:(VLCMediaList *)mediaList andName:(NSString *)name
{
    VLCMediaDocument *mediaDocument = [[VLCMediaDocument alloc] initWithMediaList:mediaList andName:name];
    [self bakeDocument:mediaDocument];
    [mediaDocument release];    
}

- (void)makeDocumentWithURL:(NSURL *)url andStartingPosition:(double)position
{
    VLCMediaDocument *mediaDocument = [[VLCMediaDocument alloc] initWithContentsOfURL:url andStartingPosition:position];
    [self bakeDocument:mediaDocument];
    [mediaDocument release];    
}

- (void)makeDocumentWithObject:(id)object
{
    if ([object isKindOfClass:[VLCMediaList class]])
        [self makeDocumentWithMediaList:object andName:nil];
    else if ([object isKindOfClass:[VLCMediaDiscoverer class]])
        [self makeDocumentWithMediaList:[object discoveredMedia] andName:[object localizedName]];
    else
        VLCAssertNotReached(@"No idea how to open that object");
}


- (void)openLibraryFromMenuItem:(id)sender
{
    [self makeDocumentWithObject:[sender representedObject]];
}

/**
 * Remember a movie that wasn't finished
 */

- (void)media:(VLCMedia *)media wasClosedAtPosition:(double)position withRemainingTime:(VLCTime *)remainingTime
{
    NSString *fileName = [[media url] lastPathComponent];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *unfinishedMovies = [NSMutableArray arrayWithArray:[defaults arrayForKey:kUnfinishedMoviesAsArray]];
    NSDictionary *thisMovie = nil;
    for (NSDictionary *dict in unfinishedMovies) {
        NSString *otherFileName = [[[dict objectForKey:@"url"] lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if ([otherFileName isEqualToString:fileName]) {
            thisMovie = [[dict retain] autorelease];
            break;
        }
    }
    if (position > 0.99) {
        if (thisMovie)
            [unfinishedMovies removeObject:thisMovie];
    }
    else {
        NSNumber *oldposition = [thisMovie objectForKey:@"position"];
        if (!oldposition || position > [oldposition doubleValue]) {
            NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:
             [[[media url] absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding], @"url",
             [NSNumber numberWithDouble:position], @"position",
             [remainingTime numberValue], @"remainingTime",
             nil];
            if (thisMovie)
                [unfinishedMovies replaceObjectAtIndex:[unfinishedMovies indexOfObject:thisMovie] withObject:dict];
            else
                [unfinishedMovies insertObject:dict atIndex:0];
        }
    }
    [defaults setObject:unfinishedMovies forKey:kUnfinishedMoviesAsArray];
}

#pragma mark -
#pragma mark NSApp delegate

- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visibleWindows
{
    [self openSplashScreen:self];
    return NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [self rebuildStyleMenu];
    
    // We have some document open already, don't bother to show the splashScreen.
    if ([[self documents] count] > 0)
        return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kDontShowSplashScreen])
        return;
    
    // auto-releases itself when the window is closed
    _splashScreen = [[VLCSplashScreenWindowController alloc] init];
    [_splashScreen showWindow:self];
}

- (IBAction)openSplashScreen:(id)sender
{
    if (!_splashScreen) {
        // auto-releases itself when the window is closed
        _splashScreen = [[VLCSplashScreenWindowController alloc] init];
    }
    [_splashScreen showWindow:self];
}

- (void)closeSplashScreen
{
    [_splashScreen release];
    _splashScreen = nil;
}

@end
