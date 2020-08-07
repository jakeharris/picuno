pico-8 cartridge // http://www.pico-8.com
version 29
__lua__


CARD_CONSTS = {}
CARD_CONSTS.width = 16
CARD_CONSTS.height = 24

-- colors: red 0, green 1, blue 2, yellow 3, wild 4
COLORS = { 
  [0] = 8, -- red
  [1] = 11, -- green
  [2] = 12, -- blue
  [3] = 10, -- yellow
  [4] = 7 -- white
}

SPECIAL_RANKS = {
  [10] = 'R',
  [11] = 'S',
  [12] = 'D',
  [13] = 'W',
  [14] = 'F'
}

deck = {}
hand = {}
cursor = 0

function _init()
  cls()

  deck = {}
  deck = generate_deck()
  deck = shuffle(deck)
  
  hand = {}
  for i = 0, 6 do
    add(hand, draw(deck))
  end

  cursor = 0

  print_deck(deck)
  render_hand(hand)
end

function _update()
  if btnp(4) then
    add(hand, draw(deck))
  end
end

function _draw()
  cls()
  --print_deck(deck)
  --render_hand(hand)
  render_cursor(cursor, hand)
end

function get_display_rank(rank)
  if rank < 10 then
    return rank -- @todo: will we run into an issue with string conversion?
  else 
    return SPECIAL_RANKS[rank]
  end
end

function render_card(card, x, y)
  rectfill(x, y, x + CARD_CONSTS.width, y + CARD_CONSTS.height, COLORS[card.color])
  print(get_display_rank(card.rank), x + 1, y + 1, 0) -- black
  print(get_display_rank(card.rank), x + CARD_CONSTS.width - 3, y + CARD_CONSTS.height - 5, 0)
end

function render_hand(cards)
  for index, card in pairs(cards) do 
    render_card(card, 4 + ((index - 1) * (CARD_CONSTS.width + 2)), 96 + 4) -- a little more than 3/4s down the screen 
  end
end

function render_cursor(cursor, hand)
  card_width = CARD_CONSTS.width + 2 -- 1-pixel border on each side. should this be in the constant?
  x = 4 + (cursor * card_width + (card_width / 2))
  spr(2, x, 96 - 10)
end

function generate_deck()
  deck = {}
  for color = 0, 3, 1 do
    for rank = 0, 12, 1 do 
      local card = {}
      card.color = color
      card.rank = rank

      add(deck, card)
      if card.rank != 0 then
        add(deck, card)
      end
    end
  end

  wild = { color = 4, rank = 13}
  wd4 =  { color = 4, rank = 14}
  for i = 0, 3 do 
    add(deck, wild) 
    add(deck, wd4)
  end

  return deck
end

function shuffle(deck) -- fisher-yates, copied from https://gist.github.com/Uradamus/10323382
  for i = #deck, 2, -1 do
    local j = -flr(-rnd(i))
    deck[i], deck[j] = deck[j], deck[i]
  end
  return deck
end

function draw(deck)
  return del(deck, deck[1])
end

function print_deck(deck)
  for index, card in pairs(deck) do
    print(get_display_rank(card.rank), flr((index - 1) / 10) * 10, ((index - 1) % 10) * 6, COLORS[card.color])
  end
end

-- LIBRARY FUNCTIONS
function ceil(x)
  return -flr(-x)
end


__gfx__
00000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077000000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700077700000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000077770000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000077700000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700077000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
