import Foundation

/// A JXA Application(pid) can still reconnect through the app's bundle after
/// an event fails. Native kernel-PID Apple Event addresses cannot launch apps.
/// These codes are Music's public scripting dictionary (Music.app's sdef).
enum MusicProcessScript {
    static let source = #"""
    function musicProcess(pid) {
      ObjC.import('AppKit');
      ObjC.import('Foundation');
      function code(s) { return s.split('').reduce((v, c) => v * 256 + c.charCodeAt(0), 0); }
      const address = $.NSAppleEventDescriptor.descriptorWithProcessIdentifier(pid);
      const root = $.NSAppleEventDescriptor.nullDescriptor;
      function spec(key, container) {
        const record = $.NSAppleEventDescriptor.recordDescriptor;
        record.setDescriptorForKeyword($.NSAppleEventDescriptor.descriptorWithTypeCode(code('prop')), code('want'));
        record.setDescriptorForKeyword($.NSAppleEventDescriptor.descriptorWithEnumCode(code('prop')), code('form'));
        record.setDescriptorForKeyword($.NSAppleEventDescriptor.descriptorWithTypeCode(code(key)), code('seld'));
        record.setDescriptorForKeyword(container, code('from'));
        return record.coerceToDescriptorType(code('obj '));
      }
      function failure(number) { const e = new Error('Music Apple Event failed: ' + number); e.number = number; throw e; }
      function send(eventClass, eventID, object, value) {
        const event = $.NSAppleEventDescriptor.appleEventWithEventClassEventIDTargetDescriptorReturnIDTransactionID(
          code(eventClass), code(eventID), address, -1, 0);
        if (object) event.setParamDescriptorForKeyword(object, code('----'));
        if (value) event.setParamDescriptorForKeyword(value, code('data'));
        const error = Ref();
        const reply = event.sendEventWithOptionsTimeoutError($.NSAppleEventSendWaitForReply | $.NSAppleEventSendNeverInteract, 2, error);
        if (!ObjC.unwrap(reply)) failure(ObjC.unwrap(error[0]) ? Number(error[0].code) : -600);
        const err = reply.paramDescriptorForKeyword(code('errn'));
        if (ObjC.unwrap(err) && Number(err.int32Value)) failure(Number(err.int32Value));
        return reply.paramDescriptorForKeyword(code('----'));
      }
      function get(key, container) { return send('core', 'getd', spec(key, container)); }
      function text(key, container) { return ObjC.unwrap(get(key, container).stringValue) || ''; }
      const app = {
        running: function() {
          const running = $.NSRunningApplication.runningApplicationWithProcessIdentifier(pid);
          return !!ObjC.unwrap(running) && !running.isTerminated && ObjC.unwrap(running.bundleIdentifier) === 'com.apple.Music';
        },
        name: () => text('pnam', root),
        playerState: function() {
          const state = Number(get('pPlS', root).enumCodeValue);
          return state === code('kPSP') ? 'playing' : state === code('kPSp') ? 'paused' : state === code('kPSS') ? 'stopped' : null;
        },
        currentTrack: function() {
          const item = get('pTrk', root);
          const track = {
            persistentID: () => text('pPIS', item),
            name: () => text('pnam', item),
            artist: () => text('pArt', item),
            album: () => text('pAlb', item),
            duration: () => Number(get('pDur', item).doubleValue),
            location: function() {
              const url = get('pLoc', item).fileURLValue;
              return ObjC.unwrap(url) ? ObjC.unwrap(url.absoluteString) : '';
            }
          };
          Object.defineProperty(track, 'lyrics', {
            get: () => () => text('pLyr', item),
            set: value => send('core', 'setd', spec('pLyr', item), $.NSAppleEventDescriptor.descriptorWithString(value))
          });
          return track;
        },
        playpause: () => send('hook', 'PlPs'),
        nextTrack: () => send('hook', 'Next'),
        previousTrack: () => send('hook', 'Prev')
      };
      Object.defineProperty(app, 'playerPosition', {
        get: () => () => Number(get('pPos', root).doubleValue),
        set: value => send('core', 'setd', spec('pPos', root), $.NSAppleEventDescriptor.descriptorWithDouble(value))
      });
      return app;
    }
    """#
}
