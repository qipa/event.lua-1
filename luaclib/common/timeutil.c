#include "timeutil.h"
#include <stdint.h>

#ifdef _WIN32
#include <winsock2.h>
#define LOCALTIME(ts,tm) localtime_s(&tm, &ts);
#else
#define LOCALTIME(ts,tm) localtime_r(&ts, &tm);
#endif

double
get_time_millis() {
	struct timeval tv;

#ifdef _WIN32

#define EPOCH_BIAS (116444736000000000)
#define UNITS_PER_SEC (10000000)
#define USEC_PER_SEC (1000000)
#define UNITS_PER_USEC (10)

	union {
		FILETIME ft_ft;
		uint64_t ft_64;
	} ft;

	GetSystemTimeAsFileTime(&ft.ft_ft);

	if (ft.ft_64 < EPOCH_BIAS) {
		return -1;
	}
	ft.ft_64 -= EPOCH_BIAS;
	tv.tv_sec = (long)(ft.ft_64 / UNITS_PER_SEC);
	tv.tv_usec = (long)((ft.ft_64 / UNITS_PER_USEC) % USEC_PER_SEC);
#else
	gettimeofday(&tv, NULL);
#endif

	return (double)tv.tv_sec * 1000 + (double)tv.tv_usec / 1000;
}

time_t
get_today_start(time_t ts) {
	if (ts == 0) {
		ts = time(NULL);
	}

	struct tm local = { 0 };
	LOCALTIME(ts, local);
	local.tm_hour = local.tm_min = local.tm_sec = 0;
	return mktime(&local);
}

time_t
get_today_over(time_t ts) {
	return get_today_start(ts) + 24 * 3600;
}

time_t
get_week_start(time_t ts) {
	if (ts == 0) {
		ts = time(NULL);
	}

	struct tm local = { 0 };
	LOCALTIME(ts, local);
	local.tm_hour = local.tm_min = local.tm_sec = 0;

	time_t week_time = mktime(&local);
	if (local.tm_wday == 0) {
		week_time -= 6 * 24 * 3600;
	} else {
		week_time -= (local.tm_wday - 1) * 24 * 3600;
	}
	return week_time;
}

time_t
get_week_over(time_t ts) {
	return get_week_start(ts) + 7 * 24 * 3600;
}

time_t
get_month_start(time_t ts) {
	if (ts == 0) {
		ts = time(NULL);
	}

	struct tm local = { 0 };
	LOCALTIME(ts, local);
	local.tm_mday = 1;
	local.tm_hour = local.tm_min = local.tm_sec = 0;
	return mktime(&local);
}

time_t
get_month_over(time_t ts) {
	if (ts == 0) {
		ts = time(NULL);
	}

	struct tm local = { 0 };
	LOCALTIME(ts, local);
	local.tm_mday = local.tm_hour = local.tm_min = local.tm_sec = 0;

	if (local.tm_mon == 11) {
		local.tm_year += 1;
		local.tm_mon = 0;
	} else { 
		local.tm_mon += 1; 
	}
	return mktime(&local);
}

int
get_diff_day(time_t ts0, time_t ts1) {
	time_t time0 = get_today_start(ts0);
	time_t time1 = get_today_start(ts1);
	return (int)(time1 - time0) / (3600 * 24);
}

int
get_diff_week(time_t ts0, time_t ts1) {
	time_t time0 = get_week_start(ts0);
	time_t time1 = get_week_start(ts1);
	return (int)(time1 - time0) / (3600 * 24 * 7);
}

time_t
get_day_time(time_t ts, int hour, int min, int sec) {
	if (ts == 0) {
		ts = time(NULL);
	}

	time_t time;
#ifdef DAY_TIME_FAST
	time = time - (time + 8 * 3600) % 86400;
#else
	time = get_today_start(ts);
#endif
	return time + hour * 3600 + min * 60 + sec;
}

time_t
get_day_time_with_sec(time_t ts, int sec) {
	return get_day_time(ts, 0, 0, sec);
}