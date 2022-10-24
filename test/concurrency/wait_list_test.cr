require "../test_helper"
require "../../src/concurrency/wait_list"

module Earl
  class WaitListTest < Minitest::Test
    def test_initialize
      list = WaitList.new
      assert_nil list.@head
      assert_nil list.@tail
    end

    def test_push
      list = WaitList.new
      a = Fiber.new {}
      b = Fiber.new {}
      c = Fiber.new {}

      list.push(a)
      assert_equal a, list.@head
      assert_equal a, list.@tail
      assert_nil a.@__earl_next

      list.push(b)
      assert_equal a, list.@head
      assert_equal b, list.@tail
      assert_equal b, a.@__earl_next
      assert_nil b.@__earl_next

      list.push(c)
      assert_equal a, list.@head
      assert_equal c, list.@tail
      assert_equal b, a.@__earl_next
      assert_equal c, b.@__earl_next
      assert_nil c.@__earl_next
    end

    def test_shift?
      list = WaitList.new
      a = Fiber.new {}
      b = Fiber.new {}
      c = Fiber.new {}

      list.push(a)
      list.push(b)
      list.push(c)

      assert_equal a, list.shift?
      assert_equal b, list.@head
      assert_equal c, list.@tail

      assert_equal b, list.shift?
      assert_equal c, list.@head
      assert_equal c, list.@tail

      assert_equal c, list.shift?
      assert_nil list.@head
    end

    def test_push_after_shift?
      list = WaitList.new
      a = Fiber.new {}
      b = Fiber.new {}

      list.push(a)
      list.shift?
      list.push(b)

      assert_equal b, list.@head
      assert_equal b, list.@tail
      assert_nil b.@__earl_next
    end

    def test_each
      list = WaitList.new
      a = Fiber.new {}
      b = Fiber.new {}
      c = Fiber.new {}

      list.push(a)
      list.push(b)
      list.push(c)

      i = 0
      list.each do |fiber|
        case i
        when 0 then assert_equal a, fiber
        when 1 then assert_equal b, fiber
        when 2 then assert_equal c, fiber
        end
        i += 1
      end
    end

    def test_each_after_shift?
      list = WaitList.new
      a = Fiber.new {}
      b = Fiber.new {}
      c = Fiber.new {}

      list.push(a)
      list.push(b)
      list.push(c)
      list.shift?

      i = 0
      list.each do |fiber|
        case i
        when 0 then assert_equal b, fiber
        when 1 then assert_equal c, fiber
        end
        i += 1
      end
    end

    def test_clear
      list = WaitList.new
      list.push(Fiber.new {})
      list.push(Fiber.new {})
      list.clear
      assert_equal nil, list.@head
    end

    def test_push_after_clear
      list = WaitList.new
      a = Fiber.new {}

      list.push(Fiber.new {})
      list.clear

      list.push(a)
      assert_equal a, list.@head
      assert_equal a, list.@tail
      assert_nil a.@__earl_next
    end

    def test_each_after_clear
      list = WaitList.new
      list.push(Fiber.new {})
      list.push(Fiber.new {})
      list.clear
      assert_equal nil, list.@head
      list.each { assert false, "expected block to have never been called" }
    end

    def test_delete_head
      list = WaitList.new
      a = Fiber.new {}
      b = Fiber.new {}
      c = Fiber.new {}

      list.push(a)
      list.delete(a)
      assert_nil list.@head

      list.push(a)
      list.push(b)
      list.push(c)
      list.delete(a)
      assert_equal b, list.@head
      assert_equal c, b.@__earl_next
      assert_equal c, list.@tail
    end

    def test_delete_tail
      list = WaitList.new
      a = Fiber.new {}
      b = Fiber.new {}
      c = Fiber.new {}

      list.push(a)
      list.push(b)
      list.push(c)
      list.delete(c)
      assert_equal a, list.@head
      assert_equal b, a.@__earl_next
      assert_equal b, list.@tail
    end

    def test_delete_inner
      list = WaitList.new
      a = Fiber.new {}
      b = Fiber.new {}
      c = Fiber.new {}

      list.push(a)
      list.push(b)
      list.push(c)
      list.delete(b)
      assert_equal a, list.@head
      assert_equal c, a.@__earl_next
      assert_equal c, list.@tail
    end
  end
end
