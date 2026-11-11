// HostedTimestamp.swift
// NomadFi
//
// A short, static time for "Updated …" lines.

import Foundation

/// Formats an update time as `5:07 PM` today and `Nov 10, 5:07 PM`
/// otherwise. Static on purpose: a relative "7 mins ago" style
/// re-renders every second and costs energy while the screen is open.
enum HostedTimestamp {
    static func text(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        calendar.isDate(date, inSameDayAs: now)
            ? date.formatted(.dateTime.hour().minute())
            : date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
