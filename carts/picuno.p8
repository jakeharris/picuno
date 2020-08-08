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
discard = {}
cursor = 1
leftmost = 1
debug_string = ''

function _init()
  cls()

  deck = {}
  deck = generate_deck()
  deck = shuffle(deck)
  
  hand = {}
  for i = 1, 7 do
    add(hand, draw(deck))
  end
  hand = sort(hand, compare_cards)

  cursor = 1
  leftmost = 1

  print_deck(deck)
  render_hand(hand, cursor, leftmost)

  discard = {}
  add(discard, draw(deck))
  render_discard(discard)
end

function _update()
  if btnp(3) then -- down (not something we actually expect to use; debugging only)
    add(hand, draw(deck))
    hand = sort(hand, compare_cards)
  end

  if btnp(4) then -- z/action/square button
    selected_card = hand[leftmost + cursor - 1]
    if can_play(selected_card, discard[#discard]) then
      played_card = del(hand, selected_card)
      add(discard, played_card)
      -- if we played the rightmost card and we have more cards 
      -- than we are displaying, scroll left one
      -- if we played the rightmost card and we can't scroll left,
      -- move the cursor left one
      if leftmost > 1 and cursor == 7 and leftmost == (#hand + 1) - 6 then
        leftmost -= 1 
      elseif cursor == #hand + 1 then
        cursor -= 1
      end
    else
      -- play an ernnt sound
    end
  end

  if btnp(1) then -- right
    if cursor == 7 then
      if leftmost < #hand - 6 then leftmost += 1 end
    elseif cursor < #hand then
      cursor += 1
    end
  end

  if btnp(0) then -- left
    if cursor == 1 then
      if leftmost > 1 then leftmost -= 1 end
    else
      cursor -= 1
    end
  end
end

function _draw()
  cls()
  print_deck(deck)
  render_hand(hand, cursor, leftmost)
  render_cursor(cursor, hand)
  render_scroll_arrows(leftmost, hand)
  render_discard(discard)

  render_debug(debug_string)
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

function render_hand(hand, cursor, leftmost)
  local visible_cards = subseq(hand, leftmost, leftmost + 6)
  for index, card in pairs(visible_cards) do 
    local x = (index - 1) * (CARD_CONSTS.width + 2)
    local y = 96 + 4 -- a little more than 3/4s down the screen 
    if index == cursor then
      y -= 1
    end
    render_card(card, x, y)
  end
end

function render_cursor(cursor, hand)
  local card_width = CARD_CONSTS.width + 2 -- 1-pixel border on each side. should this be in the constant?
  local x = ((cursor - 1) * card_width + (card_width / 2)) - 4
  local y = 96 - 4
  spr(2, x, y)
end

function render_scroll_arrows(leftmost, hand)
  if leftmost > 1 then
    spr(1, -3, 96 - 5, 1, 1, true) -- left arrow
  end

  if leftmost < #hand - 6 then
    spr(1, 128 - 8, 96 - 5, 1, 1, false) -- right arrow
  end
end

function render_discard(discard)
  render_card(discard[#discard], 64 - (CARD_CONSTS.width / 2), 96 - 2 - (CARD_CONSTS.height))
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

function compare_cards(a, b)
  av = a.color * 25 + a.rank
  bv = b.color * 25 + b.rank

  return av - bv
end

function can_play(selected, discard)
  if selected.color == 4 then -- wild
    return true
  end

  if discard.color == 4 then -- if we haven't implemented wild color selection behavior yet...
    return true
  end

  if selected.color == discard.color or selected.rank == discard.rank then
    return true
  end

  return false
end

-- LIBRARY FUNCTIONS
function ceil(x)
  return -flr(-x)
end

function subseq(seq, from, to)
  new_seq = {}

  if to == nil then
    to = #seq
  end

  for k,v in pairs(seq) do
    if k > to then break end
    if k >= from then
      add(new_seq, v)
    end
  end

  return new_seq
end

function sort(seq, comparator) -- bubble sort
  repeat 
    local done = true
    for i = 1, #seq - 1 do
      if comparator(seq[i], seq[i+1]) > 0 then
        seq[i], seq[i+1] = seq[i+1], seq[i]
        done = false
      end
    end
  until done

  return seq
end

function render_debug(string)
  print(string, 128 - 64, 4, 14)
end

__gfx__
00000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077000000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700077700000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000077770000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000077700000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700077000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
