/*
 Copyright 2016-present The Material Motion Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

extension MotionObservableConvertible {

  /**
   Emits the provided value and then emits the values emitted by the upstream.

   The returned stream will cache the last value received and immediately emit it on subscription.
   The returned stream is therefor guaranteed to always immediately emit a value upon subscription.
   */
  public func startWith(_ value: T) -> MotionObservable<T> {
    return MotionObservable(self.metadata.createChild(Metadata(#function, type: .constraint, args: [value]))) { observer in
      observer.next(value)
      return self.asStream().subscribeAndForward(to: observer).unsubscribe
    }._remember()
  }

  @available(*, deprecated, message: "Use startWith() instead.")
  public func initialValue(_ value: T) -> MotionObservable<T> {
    return MotionObservable(self.metadata.createChild(Metadata(#function, type: .constraint, args: [value]))) { observer in
      observer.next(value)
      return self.asStream().subscribeAndForward(to: observer).unsubscribe
    }
  }
}
