pico-8 cartridge // http://www.pico-8.com
version 29
__lua__


CARD_CONSTS = {}
CARD_CONSTS.width = 16
CARD_CONSTS.height = 24

-- colors: red 0, green 1, blue 2, yellow 3, wild 4
CARD_COLORS = { 
  [0] = 8, -- red
  [1] = 11, -- green
  [2] = 12, -- blue
  [3] = 10, -- yellow
  [4] = 7 -- white
}

INACTIVE_PLAYER_COLOR = 5

SPECIAL_RANKS = {
  [10] = 'R',
  [11] = 'S',
  [12] = 'D',
  [13] = 'W',
  [14] = 'F'
}

DISCARD_COORDS = {
  left = 64 - CARD_CONSTS.width - 2,
  top = 64 - CARD_CONSTS.height / 2
}

deck = {}
players = {}
discard = {}
current_player = 1
cursor = 1
leftmost = 1
turn_order = 1
is_on_deck = false
is_wild_selection_mode = false
wild_cursor = 1
debug_string = ''

wait = 0

function _init()
  cls()

  deck = {}
  deck = generate_deck()
  deck = shuffle(deck)
  
  players = {
    { name = 'you', hand = {}, ai = nil, color = nil},
    { name = 'jOEY', hand = {}, ai = joey, color = 9},
    { name = 'bOEY', hand = {}, ai = joey, color = 4},
    { name = 'gOEY', hand = {}, ai = joey, color = 14}
  }

  for i = 1, #players do
    players[i].hand = draw_first_hand()
  end 
  
  cursor = 1
  leftmost = 1
  is_on_deck = false
  is_wild_selection_mode = false
  wild_cursor = 1

  print_deck()
  render_hand()

  discard = {}
  add(discard, draw(deck))
  render_discard()
  
end

function _update()
  if current_player == 1 then
    if is_wild_selection_mode then
      handle_wild_selection_mode_input()
    elseif is_on_deck then
      handle_deck_input()
    else
      handle_input()
    end
  else 
    if wait >= 30 then
      players[current_player]['ai'](current_player)
      wait = 0
    else wait += 1 end
  end
end

function _draw()
  cls()
  render_hand()
  render_scroll_arrows()
  render_discard()
  render_deck()
  render_ai()

  if is_wild_selection_mode then
    render_wild_selection()
  elseif is_on_deck then
    render_deck_cursor()
  elseif current_player == 1 then
    render_cursor()
  end

  --render_debug()
end

function get_display_rank(rank)
  if rank < 10 then
    return rank -- @todo: will we run into an issue with string conversion?
  else 
    return SPECIAL_RANKS[rank]
  end
end

function render_card(card, x, y, is_active)
  local color = 5 -- gray/inactive
  if is_active == nil then is_active = true end
  if is_active then color = CARD_COLORS[card.color] end
  
  rectfill(x, y, x + CARD_CONSTS.width, y + CARD_CONSTS.height, color)
  print(get_display_rank(card.rank), x + 1, y + 1, 0) -- black
  print(get_display_rank(card.rank), x + CARD_CONSTS.width - 3, y + CARD_CONSTS.height - 5, 0)
end

function render_hand()
  local visible_cards = subseq(players[1].hand, leftmost, leftmost + 6)
  for index, card in pairs(visible_cards) do 
    local x = (index - 1) * (CARD_CONSTS.width + 2)
    local y = 96 + 4 -- a little more than 3/4s down the screen 
    if index == cursor and not is_on_deck and current_player == 1 then
      y -= 1
    end
    render_card(card, x, y, current_player == 1)
  end
end

function render_cursor()
  local card_width = CARD_CONSTS.width + 2 -- 1-pixel border on each side. should this be in the constant?
  local x = ((cursor - 1) * card_width + (card_width / 2)) - 4
  local y = 96 - 4
  spr(2, x, y)
end

function render_scroll_arrows()
  if leftmost > 1 then
    spr(1, -3, 96 - 5, 1, 1, true) -- left arrow
  end

  if leftmost < #players[1].hand - 6 then
    spr(1, 128 - 8, 96 - 5, 1, 1, false) -- right arrow
  end
end

function render_discard()
  render_card(
    discard[#discard], 
    DISCARD_COORDS.left, 
    DISCARD_COORDS.top
  )
end

function render_debug()
  debug_string =
    'normal mode: ' .. tostring(not is_wild_selection_mode and not is_on_deck) .. '\n' .. 
    'wild mode: ' .. tostring(is_wild_selection_mode) .. '\n'..
    'is_on_deck: ' .. tostring(is_on_deck)
  print(debug_string, 128 - 64, 4, 14)
end

function render_wild_boxes()
  local w = 3
  local h = 3
  local x = DISCARD_COORDS.left - 2 - w  -- to the left of the discard
  local y = DISCARD_COORDS.top -- starting at the top of the card
  local bm = 2

  for i = 1, 4 do
    local box_x = x
    if i == wild_cursor then box_x -= 1 end
    local box_y = y + ((i - 1) * (h + bm))
    rectfill(box_x, box_y, box_x + w, box_y + h, CARD_COLORS[i - 1])
  end
end

function render_wild_selection()
  local x = DISCARD_COORDS.left - 2 - 3 - 2 - 1 - 7  -- to the left of the discard, and the wild boxes
  local y = DISCARD_COORDS.top -- starting at the top of the card
  spr(3, x, y + ((wild_cursor - 1) * (3 + 2)) + 1, 1, 1, true) -- 3 + 2 from wild box height and bottom margin
  render_wild_boxes()
end

function render_ai()
  local y_offset = 6
  if #players == 2 then
    local y = 2
    local name_coords = get_center_text_positions(players[2].name, 64)
    local card_count_coords = get_center_text_positions(tostr(#players[2].hand), 64)
    local color = get_player_display_color(2)

    print(players[2].name, name_coords.x, y, color)
    print(#players[2].hand, card_count_coords.x, y + y_offset, color)
  end

  if #players == 3 then
    local y = 32
    local name_center = -get_center_text_positions(players[2].name).x
    local card_count_coords = get_center_text_positions(tostr(#players[2].hand), name_center)
    local color = get_player_display_color(2)

    print(players[2].name, 0, y, color)
    print(#players[2].hand, card_count_coords.x, y + y_offset, color)

    name_center = get_center_text_positions(players[3].name, 128 - 4).x
    card_count_coords = get_center_text_positions(tostr(#players[3].hand), name_center)
    color = get_player_display_color(3)

    print(players[3].name, (128 - #players[3].name * 4 - 2), y, color)
    print(#players[3].hand, card_count_coords.x, y + y_offset, color)
  end

  if #players == 4 then
    local y = 32
    local name_center = -get_center_text_positions(players[2].name).x
    local card_count_coords = get_center_text_positions(tostr(#players[2].hand), name_center)
    local color = get_player_display_color(2)

    print(players[2].name, 0, y, color)
    print(#players[2].hand, card_count_coords.x, y + y_offset, color)

    y = 2
    local name_coords = get_center_text_positions(players[3].name, 64)
    card_count_coords = get_center_text_positions(tostr(#players[3].hand), 64)
    color = get_player_display_color(3)

    print(players[3].name, name_coords.x, y, color)
    print(#players[3].hand, card_count_coords.x, y + y_offset, color)

    y = 32
    name_center = get_center_text_positions(players[4].name, 128 - 4).x
    card_count_coords = get_center_text_positions(tostr(#players[4].hand), name_center)
    color = get_player_display_color(4)

    print(players[4].name, (128 - #players[4].name * 4 - 2), y, color)
    print(#players[4].hand, card_count_coords.x, y + y_offset, color)
  end
end

function render_deck_cursor()
  local x = DISCARD_COORDS.left + CARD_CONSTS.width / 2 + CARD_CONSTS.width
  local y = DISCARD_COORDS.top - 2 - 5
  spr(2, x, y)
end

function render_deck()
  if #deck == 0 then return end

  local x = DISCARD_COORDS.left + 3 + CARD_CONSTS.width -- to the right of the discard
  local y = DISCARD_COORDS.top
  local coords = get_center_text_positions(tostr(#deck), x, y)
  rect(x, y, x + CARD_CONSTS.width, y + CARD_CONSTS.height, 7) -- white
  print(#deck, coords.x + CARD_CONSTS.width / 2, coords.y + CARD_CONSTS.height / 2, 7) -- white
end

function handle_input()
  if btnp(3) then -- down (not something we actually expect to use; debugging only)
    add(players[1].hand, draw())
    players[1].hand = sort(players[1].hand, compare_cards)
  end

  if btnp(4) then -- z/action/square button
    selected_card = players[1].hand[leftmost + cursor - 1]
    if can_play(selected_card) then
      played_card = del(players[1].hand, selected_card)
      add(discard, played_card)

      if leftmost + cursor - 1 == #players[1].hand + 1 and cursor > 1 then
        cursor -= 1
      elseif leftmost == #players[1].hand + 1 then
        leftmost -= 1
      end

      if played_card.color == 4 then
        is_wild_selection_mode = true
      else
        resolve_card(played_card)
      end
    else
      -- play an ernnt sound
      sfx(0)
    end
  end

  if btnp(1) then -- right
    if cursor == 7 then
      if leftmost < #players[1].hand - 6 then leftmost += 1 end
    elseif leftmost + cursor - 1 < #players[1].hand then
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

  if btnp(2) then -- up
    is_on_deck = true
  end
end

function handle_deck_input()
  if btnp(3) then -- down
    is_on_deck = false
  end

  if btnp(4) then -- z/action/square button
    add(players[1].hand, draw())
    sort(players[1].hand, compare_cards)
    increment_player()
    is_on_deck = false
  end
end

function handle_wild_selection_mode_input()
  if btnp(3) then -- down
    if wild_cursor == 4 then 
      wild_cursor = 1 
    else 
      wild_cursor += 1 
    end
  end

  if btnp(2) then -- up
    if wild_cursor == 1 then
      wild_cursor = 4
    else
      wild_cursor -= 1
    end
  end

  if btnp(4) then -- z/action/square button
    discard[#discard].color = wild_cursor - 1
    is_wild_selection_mode = false
    resolve_card(discard[#discard])
  end
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

  for i = 0, 3 do 
    add(deck, { color = 4, rank = 13}) 
    add(deck, { color = 4, rank = 14})
  end

  return deck
end

function shuffle(cards) -- fisher-yates, copied from https://gist.github.com/Uradamus/10323382
  for i = #cards, 2, -1 do
    local j = -flr(-rnd(i))
    cards[i], cards[j] = cards[j], cards[i]
  end
  return cards
end

function draw()
  if #deck == 0 then
    top = del(discard, discard[#discard])

    while #discard > 0 do
      current = del(discard, discard[#discard])
      if current.rank == 13 or current.rank == 14 then
        current.color = 4 -- reset wilds to wild (unselected) color
      end
      add(deck, current)
    end

    add(discard, top)
    deck = shuffle(deck)
  end

  -- @todo: do something smart here
  if #deck > 0 then
    sfx(2)
    return del(deck, deck[1])
  else
    return nil
  end
end

function print_deck()
  for index, card in pairs(deck) do
    print(get_display_rank(card.rank), flr((index - 1) / 10) * 10, ((index - 1) % 10) * 6, CARD_COLORS[card.color])
  end
end

function compare_cards(a, b)
  av = a.color * 25 + a.rank
  bv = b.color * 25 + b.rank

  return av - bv
end

function can_play(selected)
  local top_of_discard = discard[#discard]

  if selected.color == 4 then -- wild
    return true
  end

  if top_of_discard.color == 4 then -- if we haven't implemented wild color selection behavior yet...
    return true
  end

  if selected.color == top_of_discard.color or selected.rank == top_of_discard.rank then
    return true
  end

  return false
end

function draw_first_hand()
  local hand = {}
  for i = 1, 7 do
    add(hand, draw())
  end
  hand = sort(hand, compare_cards)
  return hand
end

function resolve_card(last_card)
  if last_card.rank == 10 then -- reverse
    turn_order *= -1
    if #players == 2 then increment_player() end
  elseif last_card.rank == 11 then -- skip
    increment_player()
  elseif last_card.rank == 12 then -- draw two
    increment_player()
    add(players[current_player].hand, draw())
    add(players[current_player].hand, draw())
    sort(players[current_player].hand, compare_cards)
  elseif last_card.rank == 14 then -- wild draw four
    increment_player()
    add(players[current_player].hand, draw())
    add(players[current_player].hand, draw())
    add(players[current_player].hand, draw())
    add(players[current_player].hand, draw())
    sort(players[current_player].hand, compare_cards)
  end
  increment_player()
  sfx(1)
end

function increment_player()
  current_player += turn_order

  if current_player > #players then 
    current_player = 1
  elseif current_player < 1 then 
    current_player = #players
  end
end

function get_player_display_color(player)
  if current_player == player then 
    return players[player].color 
  else 
    return INACTIVE_PLAYER_COLOR 
  end
end

-- AI LAND
function kaiba(player)
-- screw the rules, i've got money
  card = del(players[player].hand, players[player].hand[1])
  resolve_card(card)
  add(discard, card)
end

function joey(player)
  for card in all(shuffle(players[player].hand)) do
    if can_play(card) then
      card = del(players[player].hand, card)
      if card.color == 4 then -- if wild
        card.color = flr(rnd(4))
      end
      resolve_card(card)
      add(discard, card)
      return
    end
  end

  -- if we couldn't play anything...
  local card = add(players[player].hand, draw())
  if can_play(card) then
    card = del(players[player].hand, card)
    resolve_card(card)
    add(discard, card)
    return
  else
    increment_player()
  end
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

function get_center_text_positions(text, x, y)
  x = x or 0
  y = y or 0
  local text_width = 3 + 1
  local text_height = 5
  return { x = x - (#text * text_width / 2) + 1, y = y - (text_height / 2) }
end


__gfx__
00000000070000000000000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077000000777770007770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700077700000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000077770000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000077700000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700077000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000007450074500745000000000000000000000074500745007450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001c6101e150211501f10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001a6101e600226102961000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
