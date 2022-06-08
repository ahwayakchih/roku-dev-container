function main(args as Object) as Object
    return roca(args).describe("Helper", sub()
        m.it("can create Example", sub()
            item = CreateExample()
            m.assert.equal(type(item), "Node", "it should be created as a Node")
        end sub)
    end sub)
end function