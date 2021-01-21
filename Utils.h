NSDictionary* dictWithPreferences(void);
NSString* stringWithTimestamp(NSString* input);
void Log(NSString*);

static inline void TimeLog(NSString* x) {
    Log(stringWithTimestamp(x));
}