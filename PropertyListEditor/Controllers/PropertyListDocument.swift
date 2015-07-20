//
//  PropertyListDocument.swift
//  PropertyListEditor
//
//  Created by Prachi Gauriar on 7/1/2015.
//  Copyright © 2015 Quantum Lens Cap. All rights reserved.
//

import Cocoa


class PropertyListDocument: NSDocument, NSOutlineViewDataSource {
    private enum TableColumn: String {
        case Key, Type, Value
    }


    enum TreeNodeAction {
        case InsertChildAtIndex(Int)
        case RemoveChildAtIndex(Int)

        var reverseAction: TreeNodeAction {
            switch self {
            case let .InsertChildAtIndex(index):
                return .RemoveChildAtIndex(index)
            case let .RemoveChildAtIndex(index):
                return .InsertChildAtIndex(index)
            }
        }
    }


    @IBOutlet weak var propertyListOutlineView: NSOutlineView!
    @IBOutlet weak var keyTextFieldPrototypeCell: NSTextFieldCell!
    @IBOutlet weak var typePopUpButtonPrototypeCell: NSPopUpButtonCell!
    @IBOutlet weak var valueTextFieldPrototypeCell: NSTextFieldCell!


    private var tree: PropertyListTree! {
        didSet {
            self.propertyListOutlineView?.reloadData()
        }
    }


    override init() {
        self.tree = PropertyListTree()
        super.init()
    }


    // MARK: - NSDocument Methods

    override var windowNibName: String? {
        return "PropertyListDocument"
    }


    override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        self.propertyListOutlineView.expandItem(nil, expandChildren: true)
    }


    override func dataOfType(typeName: String) throws -> NSData {
        return self.tree.rootItem.propertyListXMLDocumentData()
    }


    override func readFromData(data: NSData, ofType typeName: String) throws {
        var format: NSPropertyListFormat = .XMLFormat_v1_0
        let propertyList = try NSPropertyListSerialization.propertyListWithData(data, options: [], format: &format) as! PropertyListItemConvertible

        do {
            let rootItem = try propertyList.propertyListItem()
            print("rootItem = \(rootItem)")
            self.tree = PropertyListTree(rootItem: try propertyList.propertyListItem())
        } catch let error {
            print("Error reading document: \(error)")
            throw error
        }
    }


    // MARK: - Action Methods

    @IBAction func addChild(sender: AnyObject?) {
        var rowIndex = self.propertyListOutlineView.selectedRow
        if rowIndex == -1 {
            rowIndex = 0
        }

        let treeNode = self.propertyListOutlineView.itemAtRow(rowIndex) as! PropertyListTreeNode
        self.insertItem(self.itemForAdding(), atIndex: treeNode.numberOfChildren, inTreeNode: treeNode)
    }


    @IBAction func addSibling(sender: AnyObject?) {
        let selectedRow = self.propertyListOutlineView.selectedRow

        guard selectedRow != -1,
            let selectedNode = self.propertyListOutlineView.itemAtRow(selectedRow) as? PropertyListTreeNode,
            let parentNode = selectedNode.parentNode where parentNode.item.isCollection else {
                return
        }

        let index: Int! = selectedNode.index
        self.insertItem(self.itemForAdding(), atIndex: index + 1, inTreeNode: parentNode)
    }


    @IBAction func deleteItem(sender: AnyObject?) {
        let selectedRow = self.propertyListOutlineView.selectedRow

        guard selectedRow != -1,
            let selectedTreeNode = self.propertyListOutlineView.itemAtRow(selectedRow) as? PropertyListTreeNode,
            let parentTreeNode = selectedTreeNode.parentNode where parentTreeNode.item.isCollection else {
                return
        }

        let index: Int! = selectedTreeNode.index
        self.removeItemAtIndex(index, inTreeNode: parentTreeNode)
    }


    private func insertItem(item: PropertyListItem, atIndex index: Int, inTreeNode treeNode: PropertyListTreeNode) {
        let newItem: PropertyListItem

        switch treeNode.item {
        case var .ArrayItem(array):
            array.insertElement(item, atIndex: index)
            newItem = .ArrayItem(array)
        case var .DictionaryItem(dictionary):
            dictionary.insertKey(self.keyForAddingItemToDictionary(dictionary), value: item, atIndex: index)
            newItem = .DictionaryItem(dictionary)
        default:
            return
        }

        self.setItem(newItem, inTreeNode: treeNode, nodeAction: .InsertChildAtIndex(index))
    }


    private func removeItemAtIndex(index: Int, inTreeNode treeNode: PropertyListTreeNode) {
        let newItem: PropertyListItem

        switch treeNode.item {
        case var .ArrayItem(array):
            array.removeElementAtIndex(index)
            newItem = .ArrayItem(array)
        case var .DictionaryItem(dictionary):
            dictionary.removeElementAtIndex(index)
            newItem = .DictionaryItem(dictionary)
        default:
            return
        }

        self.setItem(newItem, inTreeNode: treeNode, nodeAction: .RemoveChildAtIndex(index))
    }


    private func setItem(newItem: PropertyListItem, inTreeNode treeNode: PropertyListTreeNode, nodeAction: TreeNodeAction? = nil) {
        let oldItem = treeNode.item

        self.undoManager!.registerUndoWithHandler { [unowned self] in
            self.setItem(oldItem, inTreeNode: treeNode, nodeAction: nodeAction?.reverseAction)
        }

        treeNode.item = newItem
        if let nodeAction = nodeAction {
            switch nodeAction {
            case let .InsertChildAtIndex(index):
                treeNode.insertChildAtIndex(index)
            case let .RemoveChildAtIndex(index):
                treeNode.removeChildAtIndex(index)
            }
        }

        self.propertyListOutlineView.reloadItem(treeNode, reloadChildren: true)
    }


    // MARK: - UI Validation

    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        return self.validateAction(menuItem.action, superclassInvocation: super.validateMenuItem(menuItem))
    }


    override func validateToolbarItem(toolbarItem: NSToolbarItem) -> Bool {
        return self.validateAction(toolbarItem.action, superclassInvocation: super.validateToolbarItem(toolbarItem))
    }


    private func validateAction(action: Selector, @autoclosure superclassInvocation: Void -> Bool) -> Bool {
        let selectors = Set<Selector>(arrayLiteral: "addChild:", "addSibling:", "deleteItem:")
        if !selectors.contains(action) {
            return superclassInvocation()
        }

        let outlineView = self.propertyListOutlineView
        let treeNode: PropertyListTreeNode
        if outlineView.numberOfSelectedRows == 0 {
            treeNode = self.tree.rootTreeNode
        } else {
            treeNode = outlineView.itemAtRow(outlineView.selectedRow) as! PropertyListTreeNode 
        }

        switch action {
        case "addChild:":
            return treeNode.item.isCollection
        case "addSibling:", "deleteItem:":
            return treeNode.parentNode != nil
        default:
            return false
        }
    }


    // MARK: - Keys and Values for Adding Items

    private func keyForAddingItemToDictionary(dictionary: PropertyListDictionary) -> String {
        let formatString = NSLocalizedString("PropertyListDocument.KeyForAddingFormat",
                                             comment: "Format string for key generated when adding a dictionary item")

        var key: String
        var counter: Int = 1
        repeat {
            key = NSString.localizedStringWithFormat(formatString, counter++) as String
        } while dictionary.containsKey(key)

        return key
    }


    private func itemForAdding() -> PropertyListItem {
        return try! NSLocalizedString("PropertyListDocument.ItemForAddingStringValue",
                                      comment: "Default value when adding a new item").propertyListItem()
    }


    // MARK: - Outline View Data Source
    
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if item == nil {
            return 1
        }

        guard let treeNode = item as? PropertyListTreeNode else {
            assert(false, "item must be a PropertyListTreeNode")
        }

        return treeNode.numberOfChildren
    }


    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        guard let treeNode = item as? PropertyListTreeNode else {
            assert(false, "item must be a PropertyListTreeNode")
        }

        return treeNode.expandable
    }


    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if item == nil {
            return self.tree.rootTreeNode
        }

        guard let treeNode = item as? PropertyListTreeNode else {
            assert(false, "item must be a PropertyListTreeNode")
        }

        return treeNode.children[index]
    }


    func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
        guard let tableColumnIdentifier = tableColumn?.identifier, treeNode = item as? PropertyListTreeNode else {
            return nil
        }

        guard let tableColumn = TableColumn(rawValue: tableColumnIdentifier) else {
            assert(false, "invalid table column identifier \(tableColumnIdentifier)")
        }


        switch tableColumn {
        case .Key:
            return self.keyForTreeNode(treeNode)
        case .Type:
            return treeNode.item.propertyListType.typePopUpMenuItemIndex
        case .Value:
            return self.valueForTreeNode(treeNode)
        }
    }


//    func outlineView(outlineView: NSOutlineView, setObjectValue object: AnyObject?, forTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) {
//        guard let tableColumnIdentifier = tableColumn?.identifier, let itemNode = item as? PropertyListItemNode else {
//            return
//        }
//
//        guard let tableColumn = TableColumn(rawValue: tableColumnIdentifier) else {
//            assert(false, "invalid table column identifier \(tableColumnIdentifier)")
//        }
//
//        guard let propertyListObject = object as? PropertyListItemConvertible else {
//            assert(false, "object value (\(object)) is not a property list object")
//        }
//
//        switch tableColumn {
//        case .Key:
//            if !self.setKey(object as! String, forItemNode: itemNode) {
//                NSBeep()
//            }
//        case .Type:
//            let popUpButtonMenuItemIndex = object as! Int
//            let type = PropertyListType(typePopUpMenuItemIndex: popUpButtonMenuItemIndex)!
//            self.setItem(type.propertyListItemWithStringValue(""), ofItemNode: itemNode)
//        case .Value:
//            let item: PropertyListItem
//
//            if let popUpButtonMenuItemIndex = object as? Int,
//                case let .Value(value) = itemNode.item,
//                let valueConstraint = value.valueConstraint,
//                case let .ValueArray(valueArray) = valueConstraint {
//                    item = try! valueArray[popUpButtonMenuItemIndex].value.propertyListItem()
//            } else {
//                item = try! propertyListObject.propertyListItem()
//            }
//
//            self.setItem(item, ofItemNode: itemNode)
//        }
//    }


    func keyForTreeNode(treeNode: PropertyListTreeNode) -> NSString? {
        guard let index = treeNode.index else {
            return NSLocalizedString("PropertyListDocument.RootNodeKey", comment: "Key for root node")
        }

        // Parent node will be non-nil if index is non-nil
        switch treeNode.parentNode!.item {
        case .ArrayItem:
            let formatString = NSLocalizedString("PropertyListDocument.ArrayItemKeyFormat", comment: "Format string for array item node key")
            return NSString.localizedStringWithFormat(formatString, index)
        case let .DictionaryItem(dictionary):
            return dictionary.elementAtIndex(index).key
        default:
            return nil
        }
    }


//    func setKey(key: String, forItemNode itemNode: PropertyListItemNode) -> Bool {
//        guard let dictionaryItemNode = itemNode as? PropertyListDictionaryItemNode where !dictionaryItemNode.parent.containsChildNodeWithKey(key) else {
//            return false
//        }
//
//        let oldKey = dictionaryItemNode.key
//        guard oldKey != key else {
//            return true
//        }
//
//        guard let index = dictionaryItemNode.parent.indexOfChildNode(dictionaryItemNode) else {
//            return false
//        }
//
//        self.undoManager!.registerUndoWithHandler() { [unowned self] in
//            self.setKey(oldKey, forItemNode: itemNode)
//        }.setActionName("Set Key")
//
//        dictionaryItemNode.parent.setKey(key, forChildNodeAtIndex: index)
//        self.propertyListOutlineView.reloadItem(itemNode)
//        return true
//    }
//
//
//    func setItem(item: PropertyListItem, ofItemNode itemNode: PropertyListItemNode) {
//        let oldItem = itemNode.copy() as! PropertyListItemNode
//        self.undoManager!.registerUndoWithHandler() { [unowned self] in
//            self.setItem(oldItem.item, ofItemNode: itemNode)
//        }.setActionName("Set Value")
//
//        itemNode.item = item
//        self.propertyListOutlineView.reloadItem(itemNode, reloadChildren: true)
//    }


    func valueForTreeNode(treeNode: PropertyListTreeNode) -> AnyObject {
        switch treeNode.item {
        case .ArrayItem, .DictionaryItem:
            let formatString = NSLocalizedString("PropertyListDocument.CollectionValueFormat", comment: "Format string for values of collections")
            return NSString.localizedStringWithFormat(formatString, treeNode.numberOfChildren)
        default:
            return treeNode.item.objectValue
        }
    }


    // MARK: - Outline View Delegate

    func outlineView(outlineView: NSOutlineView, dataCellForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSCell? {
        guard let tableColumnIdentifier = tableColumn?.identifier, treeNode = item as? PropertyListTreeNode else {
            return nil
        }

        guard let tableColumn = TableColumn(rawValue: tableColumnIdentifier) else {
            assert(false, "invalid table column identifier \(tableColumnIdentifier)")
        }

        switch tableColumn {
        case .Key:
            let cell = self.keyTextFieldPrototypeCell.copy() as! NSTextFieldCell
            if case .DictionaryItem = treeNode.item {
                cell.editable = true
            } else {
                cell.editable = false
            }

            return cell
        case .Type:
            return self.typePopUpButtonPrototypeCell.copy() as! NSPopUpButtonCell
        case .Value:
            return self.valueCellForTreeNode(treeNode)
        }
    }


    func outlineView(outlineView: NSOutlineView, shouldEditTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> Bool {
        guard let tableColumnIdentifier = tableColumn?.identifier, treeNode = item as? PropertyListTreeNode else {
            return false
        }

        guard let tableColumn = TableColumn(rawValue: tableColumnIdentifier) else {
            assert(false, "invalid table column identifier \(tableColumnIdentifier)")
        }

        switch tableColumn {
        case .Key:
            guard let parentItem = treeNode.parentNode?.item else {
                return false
            }

            return parentItem.propertyListType == .DictionaryType
        case .Type:
            return true
        case .Value:
            return !treeNode.item.isCollection
        }
    }


    func valueCellForTreeNode(treeNode: PropertyListTreeNode) -> NSCell {
        let item = treeNode.item

        if item.isCollection {
            let cell = self.valueTextFieldPrototypeCell.copy() as! NSTextFieldCell
            cell.textColor = NSColor.disabledControlTextColor()
            return cell
        }

        guard let valueConstraint = item.valueConstraint else {
            return self.valueTextFieldPrototypeCell.copy() as! NSTextFieldCell
        }

        switch valueConstraint {
        case let .Formatter(formatter):
            let cell = self.valueTextFieldPrototypeCell.copy() as! NSTextFieldCell
            cell.formatter = formatter
            return cell
        case let .ValueArray(validValues):
            return self.popUpButtonCellWithValidValues(validValues)
        }
    }


    func popUpButtonCellWithValidValues(validValues: [PropertyListValidValue]) -> NSPopUpButtonCell {
        let cell = NSPopUpButtonCell()
        cell.bordered = false
        cell.font = NSFont.systemFontOfSize(NSFont.systemFontSizeForControlSize(.SmallControlSize))

        for validValue in validValues {
            cell.addItemWithTitle(validValue.title)
            cell.menu!.itemArray.last!.representedObject = validValue.value
        }

        return cell
    }
}


// MARK: - Private PropertyListType Extensions

private extension PropertyListType {
    init?(typePopUpMenuItemIndex index: Int) {
        switch index {
        case 0:
            self = .ArrayType
        case 1:
            self = .DictionaryType
        case 3:
            self = .BooleanType
        case 4:
            self = .DataType
        case 5:
            self = .DateType
        case 6:
            self = .NumberType
        case 7:
            self = .StringType
        default:
            return nil
        }
    }


    var typePopUpMenuItemIndex: Int {
        switch self {
        case .ArrayType:
            return 0
        case .DictionaryType:
            return 1
        case .BooleanType:
            return 3
        case .DataType:
            return 4
        case .DateType:
            return 5
        case .NumberType:
            return 6
        case .StringType:
            return 7
        }
    }


    func propertyListItemWithStringValue(stringValue: NSString) -> PropertyListItem {
        switch self {
        case .ArrayType:
            return .ArrayItem(PropertyListArray())
        case .BooleanType:
            return .BooleanItem(false)
        case .DataType:
            return .DataItem(PropertyListDataFormatter().dataFromString(stringValue as String) ?? NSData())
        case .DateType:
            return .DateItem(LenientDateFormatter().dateFromString(stringValue as String) ?? NSDate())
        case .DictionaryType:
            return .DictionaryItem(PropertyListDictionary())
        case .NumberType:
            return .NumberItem(NSNumberFormatter.propertyListNumberFormatter().numberFromString(stringValue as String) ?? NSNumber())
        case .StringType:
            return .StringItem(stringValue)
        }
    }
}
