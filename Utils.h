NSDictionary* dictWithPreferences(void);
NSString* stringWithTimestamp(NSString* input);
void Log(NSString*);
void setPassword(NSString* passwordToSet);
NSString* getPassword(void);

static inline void TimeLog(NSString* x) {
    Log(stringWithTimestamp(x));
}