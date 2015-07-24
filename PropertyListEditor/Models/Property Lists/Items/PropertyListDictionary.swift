//
//  PropertyListDictionary.swift
//  PropertyListEditor
//
//  Created by Prachi Gauriar on 7/19/2015.
//  Copyright © 2015 Quantum Lens Cap. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation


/// PropertyListKeyValuePairs represent key/value pairs in a property list dictionary. Each pair has
/// a key (a string) and a value (a property list item).
struct PropertyListKeyValuePair: CustomStringConvertible, Hashable {
    /// The instance’s key.
    let key: String
    
    /// The instance’s value.
    let value: PropertyListItem

    
    var description: String {
        return "\"\(self.key)\": \(self.value)"
    }


    var hashValue: Int {
        return key.hashValue ^ value.hashValue
    }


    /// Returns a new key/value pair instance with the specified key and the value of the instance.
    /// - parameter key: The key of the new instance.
    /// - returns: A copy of the instance with the specified key and the value of the instance.
    func keyValuePairBySettingKey(key: String) -> PropertyListKeyValuePair {
        return PropertyListKeyValuePair(key: key, value: self.value)
    }


    /// Returns a new key/value pair instance with the key of the instance and the specified value.
    /// - parameter value: The value of the new instance.
    /// - returns: A copy of the instance with the key of the instance and the specified value.
    func keyValuePairBySettingValue(value: PropertyListItem) -> PropertyListKeyValuePair {
        return PropertyListKeyValuePair(key: self.key, value: value)
    }
}


func ==(lhs: PropertyListKeyValuePair, rhs: PropertyListKeyValuePair) -> Bool {
    return lhs.key == rhs.key && lhs.value == rhs.value
}



/// PropertyListDictionaries represent dictionaries of property list items. These dictionaries each 
/// have an array of key/value pairs jn the dictionary.
struct PropertyListDictionary: PropertyListCollection {
    typealias ElementType = PropertyListKeyValuePair
    private(set) var elements: [PropertyListKeyValuePair] = []

    /// The set of current keys used in the instance.
    private var keySet = Set<String>()


    /// Returns an object representation of the instance.
    var objectValue: AnyObject {
        let dictionary = NSMutableDictionary()

        for element in self.elements {
            dictionary[element.key] = element.value.objectValue
        }

        return dictionary.copy()
    }


    /// Returns whether the instance contains a key/value pair with the specified key.
    /// - parameter key: The key whose membership in the instance’s key set is being checked.
    /// - returns: Whether the key is in the instance’s key set.
    func containsKey(key: String) -> Bool {
        return self.keySet.contains(key)
    }


    mutating func insertElement(element: ElementType, atIndex index: Int) {
        assert(!self.keySet.contains(element.key), "dictionary already contains key \"\(element.key)\"")
        self.keySet.insert(element.key)
        self.elements.insert(element, atIndex: index)
    }


    mutating func removeElementAtIndex(index: Int) -> ElementType {
        let element = self.elements[index]
        self.keySet.remove(element.key)
        return self.elements.removeAtIndex(index)
    }


    // MARK: - Key-Value Pair Methods

    /// Adds a key/value pair with the specified key and value to the end of the instance.
    /// - parameter key: The key being added to the instance.
    /// - parameter value: The value being added to the instance.
    mutating func addKey(key: String, value: PropertyListItem) {
        self.insertKey(key, value: value, atIndex: self.elementCount)
    }


    /// Inserts a key/value pair with the specified key and value at the specified index of the
    /// instance.
    /// - parameter key: The key of the key/value pair being inserted into the instance.
    /// - parameter value: The value of the key/value pair being inserted into the instance.
    mutating func insertKey(key: String, value: PropertyListItem, atIndex index: Int) {
        self.insertElement(PropertyListKeyValuePair(key: key, value: value), atIndex: index)
    }


    /// Replaces the key/value pair at the specified index with the specified key and value.
    /// - parameter key: The key of the key/value pair being inserted into the instance.
    /// - parameter value: The value of the key/value pair being inserted into the instance.
    /// - parameter index: The index at which the new key/value pair is being set.
    mutating func setKey(key: String, value: PropertyListItem, atIndex index: Int) {
        self.replaceElementAtIndex(index, withElement:PropertyListKeyValuePair(key: key, value: value))
    }


    /// Replaces the key of the key/value pair at the specified index.
    /// - parameter key: The key of the key/value pair being set on the instance.
    /// - parameter index: The index at which the new key/value pair is being set.
    mutating func setKey(key: String, atIndex index: Int) {
        let keyValuePair = self.elementAtIndex(index)
        self.replaceElementAtIndex(index, withElement: keyValuePair.keyValuePairBySettingKey(key))
    }


    /// Replaces the value of the key/value pair at the specified index.
    /// - parameter value: The value of the key/value pair being set on the instance.
    /// - parameter index: The index at which the new key/value pair is being set.
    mutating func setValue(value: PropertyListItem, atIndex index: Int) {
        let keyValuePair = self.elementAtIndex(index)
        self.replaceElementAtIndex(index, withElement: keyValuePair.keyValuePairBySettingValue(value))
    }
}
